#!/bin/bash

_targetdir=/mnt/tests
_downloaddir=/mnt/download
_logf=/tmp/${0##*/}.log

_install_requirements() {
	local _pycurl=python3-pycurl
	[[ $(rpm -E %rhel) = 7 ]] && {
		yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &>>${_logf:-/dev/null}
		_pycurl=python36-pycurl
	}
	yum install -y python3 $_pycurl bzip2 gzip zip xz &>>${_logf:-/dev/null}

	hash -r && command -v taskname2url.py && command -v curl-download.sh && command -v extract.sh || {
		local _downloadurl=http://download.devel.redhat.com/qa/rhts/lookaside
		local _urls="$_downloadurl/kiss-vm-ns/utils/curl-download.sh $_downloadurl/kiss-vm-ns/utils/extract.sh $_downloadurl/bkr-client-improved/utils/taskname2url.py"
		(cd /usr/bin && for _url in $_urls; do curl -Ls -O $_url; done && chmod +x *)
		local _dburl=$_downloadurl/bkr-client-improved/conf/fetch-url.ini
		(cd /etc && curl -Ls -O ${_dburl})
	}
}

_get_task_requires() {
	local _fpath=$1
	pushd "$_fpath" &>/dev/null
	{ test -f Makefile && sed -nr '/^.*"(Rhts|Repo)?Requires:\s*([^"]+)".*$/{s//\2/;s/\s+/\n/g;p}' Makefile |
		sort -u | awk '
		match($0,/^library\(([^\/]+)\/(.+)\)$/,M) { print(M[1] "/Library/" M[2]) }
		match($0,/^test\(\/?(.+)\)$/,M) { print(M[1]) }
		match($0,/^kernel-kernel-(.+)$/,M) { print("kernel/" gensub("-","?","g",M[1])) }
		match($0,/^nfs-utils-nfs-utils-(.+)$/,M) { print("nfs-utils/" gensub("-","?","g",M[1])) }
		match($0,/^\//) { print(gensub("^/","",1)) }
		match($0,/^(.+)-CoreOS-(.+)$/,M) { m1=M[1]; m2=M[2]; sub(m1 "-","",m2); print(m1 "/" gensub("-","?","g",m2)) }
		'

	  component=$(awk -F'[=/ ]+' '/^name/{print $2}' metadata);
	  awk -v head=$component -F'[=;]' '/^(task|repo)Requires/ {
		for (i=2;i<=NF;i++) {
			if ($i ~ "^/") print substr($i,2); else print head"/"$i
		}
	  }' metadata;
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
	_task=${_task#CoreOS/}; _task=${_task#/}
	read taskrepo _rpath <<<"${_task/\// }"
	uri=$(taskname2url.py /$_task $taskOpts $repoOpts)
	[[ -z "$uri" ]] && continue
	read url rpath <<<"${uri/\#/ }"
	repopath=$_targetdir/$taskrepo
	fpath="$repopath/$rpath"

	#if there is ? in rpath
	if [[ "$rpath" = *\?* && -d $repopath ]]; then
		if rfpath=$(find $repopath | grep -E "$repopath/${rpath//\?/.}$"); then
			fpath=${rfpath%/}
			if [[ -f "$fpath/.url" ]]; then
				echo "$fpath"
				return 1
			fi
			rpath=${fpath#${repopath}/}
		fi
	fi

	#skip if required task in same repo and has been there
	if [[ "$url" = "$URL" && "$taskrepo" = "$TASK_REPO" && "$REPO_PATH" != "$repopath" ]]; then
		local_fpath="$REPO_PATH/$rpath"
		if [[ -d "$local_fpath" ]]; then
			if [[ ! -f "$fpath/.url" ]]; then
				rm -rf ${fpath}
				mkdir -p "${fpath%/*}"
				ln -s $local_fpath $fpath 2>/dev/null
				echo -n "$url" >$local_fpath/.url
			fi
			echo "$local_fpath"
			return 1
		fi
	fi

	if [[ -d $fpath ]]; then
		if [[ -n "OVER_WRITE_RPM" && ! -f "$fpath/.url" ]]; then
			rm -rf "$fpath"
		else
			echo "$fpath"
			return 1
		fi
	fi

	echo -e "\n${INDENT}{debug} fetching task: /$_task -> $fpath" >&2
	file=${url##*/}
	filepath=$_downloaddir/taskrepo/$file
	#download the archive of the repo //doesn't support git protocol
	if ! test -f ${filepath}; then
		mkdir -p ${filepath%/*}
		curl-download.sh ${filepath} ${url} -s
	fi
	if test -f ${filepath}; then
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
	echo "${INDENT}{debug} install pkg dependencies of /$_task($fpath)" >&2
	pkgs=$(_get_package_requires $fpath)
	[[ -n "$pkgs" ]] && {
		echo "${INDENT}{run} yum install -y $pkgs &>>$_logf" >&2
		yum --setopt=strict=0 install -y $pkgs &>>$_logf
	}
	echo $fpath
	return 0
}

_install_task_requires() {
	INDENT+="  "
	local _fpath=$1 _task= __fpath=
	local require_tasks=$(_get_task_requires $_fpath)
	for _task in $require_tasks; do
		__fpath=$(_install_task "$_task")
		[[ $? = 0 && -d "$__fpath" ]] && _install_task_requires "$__fpath"
	done
}

#install taskname2url.py,curl-download.sh,extract.sh and db config
_install_requirements

for __task; do
	INDENT=
	__fpath=$(_install_task $__task)
	_rc=$?
	case "$_rc" in
	1) echo "{info} task ${__task} has been there -> ${__fpath}" >&2; continue;;
	2) echo "{error} fetch task ${__task} to ${__fpath} fail! " >&2; continue;;
	esac
	pushd "$__fpath";

	TASK=$__task
	_TASK=${TASK#/}; _TASK=${_TASK#CoreOS/};
	read TASK_REPO _RPATH <<<"${_TASK/\// }"
	CASE_DIR=$PWD

	echo "{debug} current dir: $CASE_DIR" >&2
	[[ -n "$REPO_URLS" ]] && echo "{debug} task urls: $REPO_URLS" >&2
	[[ -n "$TASK_URIS" ]] && echo "{debug} task urls: $TASK_URIS" >&2
	for repourl in $REPO_URLS; do [[ "$repourl" != *,* ]] && continue; repoOpts+="-repo=$repourl "; done
	for taskuri in $TASK_URIS; do [[ "$taskuri" != *,* ]] && continue; taskOpts+="-task=$taskuri "; done

	#get current task's repo and repopath
	URI=$(taskname2url.py $TASK $taskOpts $repoOpts)
	read URL RPATH <<<"${URI/\#/ }"
	REPO_PATH=${CASE_DIR%/$RPATH}

	#install task requires
	_install_task_requires .
	popd;
done
