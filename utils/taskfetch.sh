#!/bin/bash
switchroot() {
	local P=$0 SH=; [[ $0 = /* ]] && P=${0##*/}; [[ -e $P && ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		echo -e "\E[1;4m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m"
		exec sudo $SH $P "$@"
	}
}
switchroot "$@"

_targetdir=/mnt/tests
_downloaddir=/mnt/download
_logf=/tmp/${0##*/}.log
LOOKASIDE_BASE_URL=${LOOKASIDE:-http://download.devel.redhat.com/qa/rhts/lookaside}
if stat /run/ostree-booted > /dev/null 2>&1; then
	pkgInstall="rpm-ostree -A --assumeyes --idempotent --allow-inactive install"
	pkgUnInstall="rpm-ostree uninstall"
else
	pkgInstall="yum -y install --setopt=strict=0"
	pkgUnInstall="yum -y remove"
fi

_install_requirements() {
	if ps axf|grep -v "^ *$$ "|grep -q 'taskfetch.sh  *--install-dep[s]'; then
		while ps axf|grep -v "^ *$$ "|grep -q 'taskfetch.sh  *--install-dep[s]'; do sleep 2; done
		return 0
	fi
	[[ $(rpm -E %rhel) = 7 ]] && {
		$pkgInstall https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &>>${_logf:-/dev/null}
		sed -i -e /skip_if_unavailable/d -e '/enabled=1/askip_if_unavailable=1' /etc/yum.repos.d/epel.repo
	}
	local _pkgs="python3 bzip2 gzip zip xz expect man-db restraint-rhts beakerlib"
	_pkgs=$(rpm -q $_pkgs > >(awk '/not.installed/{print $2}')) ||
		$pkgInstall $_pkgs &>>${_logf:-/dev/null}

	local _urls=()
	hash -r
	command -v curl-download.sh || _urls+=(${LOOKASIDE_BASE_URL}/kiss-vm-ns/utils/curl-download.sh)
	command -v extract.sh       || _urls+=(${LOOKASIDE_BASE_URL}/kiss-vm-ns/utils/extract.sh)
	command -v taskname2url.py  || _urls+=(${LOOKASIDE_BASE_URL}/bkr-client-improved/utils/taskname2url.py)
	(cd /usr/bin && for _url in "${_urls[@]}"; do curl -Ls --retry 64 --retry-delay 2 -O $_url; chmod +x ${_url##*/}; done)

	local _dburl=${LOOKASIDE_BASE_URL}/bkr-client-improved/conf/fetch-url.ini
	[[ -f /etc/${_dburl##*/} ]] || (cd /etc && curl -Ls --retry 64 --retry-delay 2 -O ${_dburl})
}

get_taskname() {
	local casedir=$1; make -C $casedir testinfo.desc &>/dev/null
	if [[ -f $casedir/metadata ]]; then
		awk -F'[ =]+' '$1 == "name" {print $2}' $casedir/metadata
	elif [[ -f $casedir/testinfo.desc ]]; then
		awk -F'[: =\t]+' '/^Name:/{print $2}' $casedir/testinfo.desc
	fi
}

_get_task_requires() {
	local _fpath=$1
	pushd "$_fpath" &>/dev/null
	local _reponame=$(get_taskname .|awk -F/ '{if ($2 != "CoreOS") {print $2} else {print $3}}')
	{
	if [[ -f metadata ]]; then
	  _reponame=$(awk -F'[=/ ]+' '/^name/{if ($2 != "CoreOS") {print $2} else {print $3}}' metadata);
	  awk -v head=$_reponame -F'[=;]' '/^(task|orepo|repo)Requires= *[^ ]+/ {
		for (i=2;i<=NF;i++) {
			if ($i == "") continue
			if ($i ~ "^/") print substr($i,2); else print head"/"$i
		}
	  }' metadata;
	elif test -f Makefile; then
	  sed -nr '/^.*"(Rhts|Repo)?Requires:\s*([^"]+)".*$/{s//\2/;s/\s+/\n/g;p}' Makefile |
		sort -u | awk -v repon=$_reponame '
		match($0,/^library\(([^\/]+)\/(.+)\)$/,M) { print(M[1] "/Library/" M[2]); next }
		match($0,/^test\(\/?(.+)\)$/,M) { print(M[1]); next }
		match($0,/^kernel-kernel-(.+)$/,M) { print("kernel/" gensub("-","?","g",M[1])); next }
		match($0,/^nfs-utils-nfs-utils-(.+)$/,M) { print("nfs-utils/" gensub("-","?","g",M[1])); next }
		match($0,/^\//) { print(gensub("^/","",1)); next }
		match($0,/^(.+)-CoreOS-(.+)$/,M) { m1=M[1]; m2=M[2]; sub(m1 "-","",m2); print(m1 "/" gensub("-","?","g",m2)); next }
		match($0,/^.+\//) { print repon"/"$0; next }
		'
	fi
	} 2>/dev/null | sort -u | xargs
	popd &>/dev/null
}

_get_package_requires() {
	local _fpath=$1
	pushd "$_fpath" &>/dev/null
	{ sed -nr '/^.*"Requires:\s*([^"()]+)" .*$/{s//\1/;s/ +/\n/g;p}' $_fpath/Makefile |
		grep -E -v '^kernel-kernel-|^(.+)-CoreOS-\1-|^/';
	} 2>/dev/null | sort -u | xargs
	popd &>/dev/null
}

_install_task() {
	local _task=$1 fpath= local_fpath=
	local taskrepo= _rpath= url= rpath=
	_task=${_task#CoreOS/}; _task=${_task#/}
	[[ -z "$_task" ]] && { return 2; }
	read taskrepo _rpath <<<"${_task/\// }"
	read uri _ < <(taskname2url.py /$_task $taskOpts $repoOpts)
	[[ -z "$uri" ]] && { echo "{warn} 'taskname2url.py /$_task $taskOpts $repoOpts' fail, or this task disable fetch-url" >&2; return 2; }
	[[ "$uri" != http* && "$uri" != ftp* ]] && {
		echo "{warn} 'taskfetch.sh now only support http[s]/ftp protocols'" >&2; return 2; }
	read url rpath <<<"${uri/\#/ }"
	repopath=$_targetdir/$taskrepo
	fpath="$repopath/$rpath"

	if [[ -L ${repopath} && "$(readlink -f $repopath)" = "${REPO_PATH}" && -d ${fpath} ]]; then
		return 0
	fi

	[[ "$FORCE" -gt 0 && -d "$fpath" ]] && { [[ "$(cat $fpath/.pid 2>/dev/null)" != $$ ]] && rm -rf "${fpath}"; }
	[[ "$_rpath" != "$rpath" ]] && { rm -rf "$repopath/${_rpath}"; mkdir -p "$repopath/${_rpath%/*}"; ln -sf "$fpath" "$repopath/${_rpath}"; }

	#if there is ? in rpath
	if [[ "$rpath" = *\?* && -d $repopath ]]; then
		if rfpath=$(find $repopath | grep -E "$repopath/${rpath//\?/.}$"); then
			fpath=${rfpath%/}
			if [[ -f "$fpath/.url" ]]; then
				echo "$fpath"
				_get_task_requires "$fpath" 2>/dev/null|grep -q /Library/ && return 8 || return 1
			fi
			rpath=${fpath#${repopath}/}
		fi
	fi

	#skip if required task in same repo and has been there
	if [[ "$url" = "$URL" && "$taskrepo" = "$TASK_REPO" && "$(readlink -f $REPO_PATH)" != "$(readlink -f $repopath)" ]]; then
		local_fpath="$REPO_PATH/$rpath"
		if [[ -d "$local_fpath" ]]; then
			if [[ ! -f "$fpath/.url" ]]; then
				rm -rf ${fpath}
				mkdir -p "${fpath%/*}"
				ln -s $local_fpath $fpath 2>/dev/null
				echo -n "$url" >$local_fpath/.url
			fi
			echo "$local_fpath"
			_get_task_requires "$local_fpath" 2>/dev/null|grep -q /Library/ && return 8 || return 1
		fi
	fi

	if [[ -d $fpath ]]; then
		if [[ -n "$OVER_WRITE_RPM" && ! -f "$fpath/.url" ]]; then
			rm -rf "$fpath"
		else
			echo "$fpath"
			_get_task_requires "$fpath" 2>/dev/null|grep -q /Library/ && return 8 || return 1
		fi
	fi

	echo -e "\n${INDENT}{debug} fetching task: /$_task -> $fpath" >&2
	local file=${url##*/}
	[[ "$FORCE" -gt 1 ]] && { file+=-$$; }
	filepath=$_downloaddir/taskrepo/$file
	#download the archive of the repo //doesn't support git protocol
	if [[ ! -f ${filepath} ]]; then
		mkdir -p ${filepath%/*}; rm ${filepath%$$}* -f
		curl-download.sh -otimeo=360,retry=6 ${filepath} ${url} -s|& sed "s/^/$INDENT/" >&2
		[[ "$FORCE" -gt 1 ]] && { ln -f ${filepath} ${filepath%-$$}; }
	fi
	if test -f ${filepath}; then
		[[ "$rpath" = *\?* ]] &&
			rpath=$(extract.sh ${filepath} --list --path=${rpath}|sed -rn '1{s@^[^/]+/@@;s@/$@@;p;q}')
		extract.sh ${filepath} $_targetdir $taskrepo --path=${rpath}|& sed "s/^/$INDENT/" >&2
		fpath="$repopath/$rpath";
		[[ -n "$local_fpath" ]] && local_fpath="$REPO_PATH/$rpath"
		[[ -n "$local_fpath" && ! -d "$local_fpath" ]] && {
			mkdir -p "${local_fpath%/*}"
			ln -sf "$fpath" "$local_fpath"
		}
	else
		echo "${INDENT}{error} download $url to ${filepath} fail" >&2
		return 2
	fi
	echo -n "$url" >$fpath/.url
	echo -n "$$" >$fpath/.pid
	echo "${INDENT}{debug} install pkg dependencies of /$_task($fpath)" >&2
	pkgs=$(_get_package_requires $fpath)
	[[ -n "$pkgs" ]] && {
		echo "${INDENT}{run} $pkgInstall $pkgs &>>${_logf:-/dev/null}" >&2
		$pkgInstall $pkgs &>>${_logf:-/dev/null}
	}
	echo $fpath
	return 0
}

_install_task_requires() {
	INDENT+="  "
	local onlyBkrLibrary=
	[[ "$1" = -bkrlib ]] && { shift; onlyBkrLibrary=yes; }
	local _fpath=$1 _task= __fpath=
	local require_tasks=$(_get_task_requires $_fpath)
	for _task in $require_tasks; do
		[[ "$onlyBkrLibrary" = yes && $_task != */Library/* ]] && continue
		__fpath=$(_install_task "$_task"); rc=$?
		[[ -d "$__fpath" ]] && {
			if [[ "$rc" = 0 ]]; then
				_install_task_requires "$__fpath"
			elif [[ "$rc" = 8 ]]; then
				_install_task_requires -bkrlib "$__fpath"
			fi
		}
	done
	INDENT="${INDENT%  }"
}

Usage() {
	cat <<-EOF
	Usage: ${0##/*/} [-h] </task/name [/task2/name ...]> [-f] [--repo=<rname@url>] [--task=</task/name@url#/relative/path>]"
	Example:
	  ${0##/*/} /nfs-utils/services/systemd/rpcgssd /kernel/filesystems/nfs/nfstest/nfstest_ssc
	  ${0##/*/} /kernel/networking/tipc/tipcutils/fuzz -f  #force re-{extract}
	  ${0##/*/} /kernel/networking/tipc/tipcutils/fuzz -ff #force re-{download and extract}
	  ${0##/*/} /kernel/filesystems/nfs/pynfs --repo=kernel@http://fs-qe.usersys.redhat.com/ftp/pub/jiyin/kernel-test.tgz
	  ${0##/*/} -f --task=/kernel/fs/nfs/nfstest/nfstest_delegation@https://github.com/tcler/linux-network-filesystems/archive/refs/heads/master.tar.gz#testcases/nfs/nfstest/nfstest_delegation
	  ${0##/*/} --run /nfs-utils/stress/fast-mount-local RESVPORT=yes
	EOF
}

#treat arg that looks like var=val as env
for a; do [[ "$a" =~ ^[a-zA-Z_][a-zA-Z0-9_]*=.+ ]] && ENV+=("$a") || at+=("$a"); shift; done
set -- "${at[@]}"

REPO_URLS+=${REPO_URLS:+ }
TASK_URIS+=${TASK_URIS:+ }
_at=`getopt -o fh \
    --long repo: \
    --long task: \
    --long run   \
    --long fetch-require \
    --long install-deps \
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h) Usage; shift; exit 0;;
	-f) let FORCE++; shift;;
	--repo) [[ "REPO_URLS" != *${2}* ]] && REPO_URLS+="$2 "; shift 2;;
	--task) [[ "TASK_URIS" != *${2}* ]] && TASK_URIS+="$2 "; taskl+=(${2%%[,@]*}); shift 2;;
	--run)  RUN_TASK=yes; shift;;
	--fetch-require) FETCH_REQUIRE=yes; shift;;
	--install-deps) _install_requirements; shift; exit 0;;
	--) shift; break;;
	esac
done
eval set -- "$@" "${taskl[@]}"
[[ $# = 0 ]] && { Usage >&2; exit 1; }

#install taskname2url.py,curl-download.sh,extract.sh and db config
_install_requirements
[[ -n "$REPO_URLS" ]] && echo "{debug} task urls: $REPO_URLS" >&2
[[ -n "$TASK_URIS" ]] && echo "{debug} task urls: $TASK_URIS" >&2
for repourl in $REPO_URLS; do
	[[ "$repourl" != *[,@]* ]] && continue
	[[ "$taskuri" = *[,@]git:// ]] && continue
	repoOpts+="-repo=$repourl "
done
for taskuri in $TASK_URIS; do
	[[ "$taskuri" != *[,@]* ]] && continue
	[[ "$taskuri" = *[,@]git:// ]] && continue
	taskOpts+="-task=$taskuri "
done

for __task; do
	INDENT=
	URL=
	RPATH=
	REPO_PATH=

	if [[ -d "$__task" || "$FETCH_REQUIRE" = yes ]]; then
		__fpath=$(readlink -f $__task)
		TASK="${TESTNAME:-$RSTRNT_TASKNAME}"
		#for local test
		if [[ -z "$TASK" ]]; then
			TASK="$(get_taskname $__fpath)"
			[[ -z "$TASK" ]] && { echo "{warn} can not get taskname from '$__fpath'" >&2; continue; }
		fi
	else #fetch task
		__fpath=$(_install_task $__task)
		_rc=$?
		case "$_rc" in
		2) echo "{error} fetch task ${__task} to ${__fpath} fail! " >&2; continue;;
		1) { echo "{info} task ${__task} has been there -> ${__fpath}" >&2; [[ "$RUN_TASK" != yes ]] && continue; }; ;;
		esac
		TASK=$__task
	fi

	pushd "$__fpath" &>/dev/null
	_TASK=${TASK#/}; _TASK=${_TASK#CoreOS/};
	read TASK_REPO _RPATH <<<"${_TASK/\// }"

	CASE_DIR=$PWD
	echo "{debug} current dir: $CASE_DIR" >&2
	#get current task's repo and repopath
	read URI _ < <(taskname2url.py $TASK $taskOpts $repoOpts)
	read URL RPATH <<<"${URI/\#/ }"
	REPO_PATH=${CASE_DIR%/$RPATH}

	#install task requires
	_install_task_requires .

	if [[ "$RUN_TASK" = yes ]]; then
		(for env in "${ENV[@]}"; do eval export ${env%%=*}=\${env#*=}; done
		export TEST=$TASK TESTNAME=$TASK RSTRNT_TASKNAME=$TASK
		if [[ -f metadata ]]; then
			eval "$(sed -rn '/^entry_point *= */{s///;p}' metadata)"
		else
			make run
		fi
		) &> >(tee taskout.log)
	fi
	popd &>/dev/null
done
