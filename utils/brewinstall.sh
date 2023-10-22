#!/bin/bash
# Description: to install brew/koji scratch build or 3rd party pkgs
# Author: Jianhong Yin <jiyin@redhat.com>

P=$0; [[ $0 = /* ]] && P=${0##*/}
switchroot() {
	[[ $(id -u) != 0 ]] && {
		echo -e "{WARN} $P need root permission, switch to:\n  sudo $P $@" | GREP_COLORS='ms=1;30' grep --color=always . >&2
		exec sudo $P "$@"
	}
}
switchroot "$@"

LANG=C
bkrDownloadUrl=https://raw.githubusercontent.com/tcler/bkr-client-improved/master
downloadBaseUrl=http://download.devel.redhat.com

is_available_url() {
        local _url=$1
        curl --connect-timeout 8 -m 16 --output /dev/null --silent --head --fail $_url &>/dev/null
}
is_rh_intranet() { host ipa.redhat.com &>/dev/null; }

[[ function = "$(type -t report_result)" ]] || report_result() {  echo "$@"; }

P=${0##*/}
KOJI=brew
KREBOOT=yes
INSTALL_TYPE=undefine

retcode=0
prompt="[${KOJI}-install]"
run() {
	local cmdline=$1
	local expect_ret=${2:-0}
	local comment=${3:-$cmdline}
	local ret=0

	echo "[$(date +%T) $USER@ ${PWD%%*/}]# $cmdline"
	eval $cmdline
	ret=$?
	[[ $expect_ret != - && $expect_ret != $ret ]] && {
		report_result "$comment" FAIL
		let retcode++
	}

	return $ret
}

Usage() {
	cat <<-EOF
	Usage:
	 $P <[brew_scratch_build_id] | [lstk|rtk|upk|brew_build_name] | [url]> [-koji] [-debugk] [-noreboot] [-depthLevel=\${N:-2}] [-debuginfo] [-onlydebuginfo] [-onlydownload] [-arch=\$arch] [-R= +R= -A=]

	Example:
	 $P 23822847  # brew/koji scratch build id
	 $P kernel-4.18.0-147.8.el8    # brew/koji build name
	 $P [ftp|http]://url/xyz.rpm   # install xyz.rpm
	 $P nfs:server/nfsshare        # install all rpms in nfsshare
	 $P repo:rname,url             # install all rpms in repo rname
	 $P lstk                       # install latest release kernel
	 $P lstk -debuginfo            # install latest release kernel and it's -debuginfo package
	 $P lstk -debugk               # install latest release debug kernel
	 $P upk                        # install latest upstream kernel
	 $P rtk                        # install rt kernel
	 $P [ftp|http]://url/path/ [-depthLevel=N]  # install all rpms in url/path, default download depth level 2
	 $P kernel-4.18.0-148.el8 -onlydebuginfo    # install -debuginfo pkg of kernel-4.18.0-148.el8
	 $P -onlydownload [other option] <args>     # only download rpms and exit
	 $P -onlydownload -arch=src,noarch kernel-4.18.0-148.el8  # only download src and noarch package of build kernel-4.18.0-148.el8
EOF
}

# Install scratch build package
[ -z "$*" ] && {
	Usage >&2
	exit
}

is_rh_intranet && {
	Intranet=yes
	bkrDownloadUrl=http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved
}

install_brew() {
	which brew &>/dev/null || {
		which brewkoji_install.sh &>/dev/null || {
			_url=$bkrDownloadUrl/utils/brewkoji_install.sh
			mkdir -p ~/bin && curl -o ~/bin/brewkoji_install.sh -s -L $_url
			chmod +x ~/bin/brewkoji_install.sh
		}
		PATH=~/bin:$PATH brewkoji_install.sh >/dev/null || {
			echo "{WARN} install brewkoji failed" >&2
			exit 1
		}
	}
	which brew
}

getUrlListByUrl() {
	local purl=$1
	curl -Ls ${purl} | sed -rn '/.*>(.*.rpm)<.*/{s//\1/;p}' | xargs -I@ echo "$purl@"
}

getUrlListByRepo() {
	local repopath=$1
	local reponame=
	local url=
	local rpms=

	if [[ "$repopath" =~ ^(ftp|http|https):// ]]; then
		repopath=repo-$RANDOM,$repopath
	fi

	read reponame url <<< "${repopath/,/ }"

	verx=$(rpm -E %rhel)
	[[ "$verx" != %rhel && "$verx" -le 7 ]] && yum install -y yum-utils &>/dev/null
	: <<-'COMM'
	#install dependency
	yum install -y perl python3 binutils iproute-tc nmap-ncat perf

	#get package list from repo
	if [[ "$verx" != %rhel && "$verx" -le 7 ]]; then
		rpms=$(repoquery -a --repoid=$reponame --repofrompath=$repopath)
	else
		rpms=$(yum  --disablerepo=* --repofrompath=$repopath  rq $reponame \* 2>/dev/null)
	fi
	if [[ -z "$rpms" ]]; then
		echo "{WARN} get rpms from repo($reponame) fail" >&2
		return 1
	fi

	#download package list
	if [[ "$verx" != %rhel && "$verx" -le 7 ]]; then
		yum --disablerepo=* repo-pkgs $reponame install $rpms \
			--downloadonly --skip-broken -y --nogpgcheck --downloaddir=.
	else
		yum --disablerepo=* --repofrompath=$repopath repo-pkgs $reponame install $rpms \
			--downloadonly --skip-broken -y --nogpgcheck --destdir=.
	fi
	COMM

	if [[ "$verx" != %rhel && "$verx" -le 7 ]]; then
		cat <<-REPO >/etc/yum.repos.d/${reponame}.repo
		[$reponame]
		name=$reponame
		baseurl=$url
		enabled=1
		gpgcheck=0
		skip_if_unavailable=1
		REPO
		urls=$(yumdownloader --url --disablerepo=* --enablerepo=$reponame \*|grep '\.rpm$')
	else
		urls=$(yum download --url --disablerepo=* --repofrompath=$repopath \*|grep '\.rpm$')
	fi
	echo "$urls"
}

RejectOpts=()
AcceptOpts=()

autoAcceptOpts=()
autoRejectOpts=()

rpmFilter() {
	local afs=()
	local rfs=()
	local nrfs=()
	local pattype=glob url= file=
	local reject= accept=
	for arg; do
		case "$arg" in
		-re) pattype=regex;;
		-A*) afs+=("${arg#-A}");;
		-R*) rfs+=("${arg#-R}");;
		+R*) nrfs+=("${arg#+R}");;
		esac
	done
	_match() {
		local pt=$1
		if [[ $pt = glob ]]; then
			[[ "$2" = $3 ]]
		else
			[[ "$2" =~ $3 ]]
		fi
	}
	echo "[rpmFilter] accepts: ${afs[*]}" >&2
	echo "[rpmFilter] rejects: ${rfs[*]}" >&2
	echo "[rpmFilter] rejects!: ${nrfs[*]}" >&2
	while read url; do
		#echo "[rpmFilter] _check: $url" >&2
		file=${url##*/}
		reject=0
		for pat in "${rfs[@]}"; do _match $pattype "$file" "$pat" && { reject=1; break; }; done
		[[ "$reject" = 1 ]] && continue
		for pat in "${nrfs[@]}"; do _match $pattype "$file" "$pat" || { reject=1; break; }; done
		[[ "$reject" = 1 ]] && continue

		accept=1; [[ ${#afs[@]} > 0 ]] && accept=0
		for pat in "${afs[@]}"; do _match $pattype "$file" "$pat" && { accept=1; break; }; done
		[[ "$accept" = 1 ]] && {
			echo -e "\E[01;36m[rpmFilter] accept: $url\E[0m" >&2
			echo "$url"
		}
	done
}

buildname2url() {
	local _build=$1
	local url= _paths=
	local rc=1
	_paths=$(brew buildinfo $_build|grep -E -o "/brewroot/vol/.*/(${archPattern})/"|uniq)
	[[ -z "$_paths" ]] && {
		_paths=$(koji buildinfo $_build|grep -E -o "/packages/.*/(${archPattern})/"|uniq)
		downloadBaseUrl=https://kojipkgs.fedoraproject.org
	}
	if [[ -n "$_paths" ]]; then
		echo "{debug} paths: $_paths" >&2
		for _path in $_paths; do
			url=$(curl -Ls -o /dev/null -w %{url_effective} $downloadBaseUrl/$_path)
			echo "{debug} url: $url" >&2
			if is_available_url $url; then
				echo $url
				rc=0
			fi
		done
	fi

	return $rc
}

_curl_download() {
	local url=$1 ourl=
	curl -L -k $url -O || {
		ourl=$url
		url=$(curl -Ls -o /dev/null -w %{url_effective} $ourl)
		if [[ "$url" != "$ourl" ]]; then
			curl -L -k $url -O
		fi
	}
}

batch_download() {
	local dtype=
	[[ "$1" = -p ]] && dtype=parallel
	if [[ "$dtype" = parallel ]]; then
		while read url; do
			echo "_curl_download $url &"
			_curl_download $url &
		done
		wait
	else
		while read url; do
			run "_curl_download $url"
		done
	fi
}

download_pkgs_from_repo() {
	local repopath=$1
	time batch_download -p < <(getUrlListByRepo $repopath |
		rpmFilter "${autoRejectOpts[@]}" "${autoAcceptOpts[@]}" "${RejectOpts[@]}" "${AcceptOpts[@]}")
}

download_rpms_from_url() {
	local purl=$1
	time batch_download -p < <(getUrlListByUrl $purl |
		rpmFilter "${autoRejectOpts[@]}" "${autoAcceptOpts[@]}" "${RejectOpts[@]}" "${AcceptOpts[@]}")
}

ParallelDownload()
{

	local temp_urls="${1:-$(cat)}"
	[[ -z "${temp_urls[*]}" ]] && return 1
	[ -n "${temp_urls[*]}" ] &&\
	echo ${temp_urls[*]} | xargs -P0 -n1 curl -LSks -C0 -O --retry 16 --max-time 3600 --connect-timeout 60 --speed-time 3600 --ignore-content-length -w '%{url_effective} %{speed_download} bps total_size %{size_download} bytes download_time %{time_total} second\n'
}

getUrlListByPCurl()
{
	# receive a temp_urls to do more judge

	local urls=()
	local temp_urls="${1:-$(cat)}"

	temp_urls=$(echo "${temp_urls}" | tr '\n' ' ' | sed 's/^[ \t]*//;s/[ \t]*$//')
	IFS=' ' read -ra UrlList <<< "${temp_urls}"
	[[ -z "${UrlList[*]}" ]] && return 1

	# if a single url will found rpms. if a mutiple url will splice a complete path
	if [ ${#UrlList[@]} -qe 1 ]; then
			urls=$(curl -Ls "${UrlList}" | sed -rn '/.*>(.*.rpm)<.*/{s//\1/;p}' | xargs -I@ echo "${UrlList}@")
	elif [ ${#UrlList} -eq 0 ]; then
		echo "didn't got any url"
		return 1
	else
		for index in ${!UrlList[@]}; do
			urls+="$downloadBaseUrl/${UrlList[$index]} "
		done
	fi
	# output urls to download
	echo "${urls[*]}"
}

# parse options
builds=()
for arg; do
	case "$arg" in
	-koji)           KOJI=koji;;
	-debuginfo)      DEBUG_INFO_OPT=--debuginfo; DEBUG_INFO=yes;;
	-onlydebuginfo)  DEBUG_INFO_OPT=--debuginfo; ONLY_DEBUG_INFO=yes; KREBOOT=no;;
	-onlydownload)   ONLY_DOWNLOAD=yes;;
	-debug|-debugk*) FLAG=debugkernel;;
	-noreboot*)      KREBOOT=no;;
	-A=*)            AcceptOpts+=("-A${arg#-A=}");;
	-R=*)            RejectOpts+=("-R${arg#-R=}");;
	+R=*)            RejectOpts+=("+R${arg#+R=}");;
	-depthLevel=*)   depthLevel=${arg/*=/};;
	-rpms*)          INSTALL_TYPE=rpms;;
	-yum*)           INSTALL_TYPE=yum;;
	-rpm)            INSTALL_TYPE=rpm;;
	-arch=*)         _ARCH=${arg/*=/};;
	-h)              Usage; exit;;
	-*)              echo "{WARN} unkown option '${arg}'";;
	*)
			builds+=($arg)
			if [[ "$arg" = kernel-rt* ]]; then
				builds+=(rtk)
			elif [[ "$arg" = kernel-64k* ]]; then
				builds+=(64k)
			fi
		;;
	esac
done

if [[ "${#autoRejectOpts[@]}" = 0 ]]; then
	if ! grep -E -w 'rtk|kernel-rt|64k|kernel-64k' <<<"${builds[*]}"; then
		autoRejectOpts+=(-Rkernel-rt*.rpm -Rkernel-64k*.rpm)
	elif ! grep -E -w 'rtk|kernel-rt' <<<"${builds[*]}"; then
		autoRejectOpts+=(-Rkernel-rt*.rpm +Rkernel-64k*.rpm)
	elif ! grep -E -w '64k|kernel-64k' <<<"${builds[*]}"; then
		autoRejectOpts+=(-Rkernel-64k*.rpm +Rkernel-rt*.rpm)
	fi
fi
if [[ "$FLAG" = debugkernel ]]; then
	autoRejectOpts+=(+R*debug-*.rpm)
else
	autoRejectOpts+=(-R*debug-*.rpm)
fi
if [[ "$DEBUG_INFO" != yes && "$ONLY_DEBUG_INFO" != yes ]]; then
	autoRejectOpts+=(-R*debuginfo*.rpm)
fi
if [[ "$ONLY_DEBUG_INFO" = yes ]]; then
	autoRejectOpts+=(+R*debuginfo*.rpm)
fi

autoRejectOpts+=(+Rkernel*)
! grep -q -w virt <<<"${RejectOpts[*]} ${AcceptOpts[*]}" && autoRejectOpts+=(-R*-virt-*.rpm)
! grep -q -w devel <<<"${RejectOpts[*]} ${AcceptOpts[*]}" && autoRejectOpts+=(-R*-devel-*.rpm)
! grep -q -w tools <<<"${RejectOpts[*]} ${AcceptOpts[*]}" && autoRejectOpts+=(-R*-tools-*.rpm)
! grep -q -w doc <<<"${RejectOpts[*]} ${AcceptOpts[*]}" && autoRejectOpts+=(-R*-doc-*.rpm)
! grep -q -w selftest <<<"${RejectOpts[*]} ${AcceptOpts[*]}" && autoRejectOpts+=(-R*-selftest-*.rpm)

# fix ssl certificate verify failed
# https://certs.corp.redhat.com/ https://docs.google.com/spreadsheets/d/1g0FN13NPnC38GsyWG0aAJ0v8FljNDlqTTa35ap7N46w/edit#gid=0
(cd /etc/pki/ca-trust/source/anchors && curl -Ls --remote-name-all https://certs.corp.redhat.com/{2022-IT-Root-CA.pem,2015-IT-Root-CA.pem,ipa.crt,mtls-ca-validators,RH-IT-Root-CA.crt} && update-ca-trust)

if [[ ${#builds[@]} = 0 ]]; then
	if [[ "$FLAG" = debugkernel || "$ONLY_DEBUG_INFO" = yes ]]; then
		builds+=(kernel-$(uname -r|sed 's/\.[^.]*$//'))
	else
		Usage >&2
		exit
	fi
fi

archList=($(arch) noarch)
[[ -n "$_ARCH" ]] && archList=(${_ARCH//,/ })
archPattern=$(echo "${archList[*]}"|sed 's/ /|/g')
if [[ "$FLAG" = debugkernel ]]; then
	if [[ "$DEBUG_INFO" = yes ]]; then
		autoAcceptOpts=()
		for a in "${archList[@]}"; do autoAcceptOpts+=("-A*debug*.${a}.rpm"); done
	else
		autoAcceptOpts=()
		for a in "${archList[@]}"; do autoAcceptOpts+=("-A*debug-*.${a}.rpm"); done
	fi
else
	autoAcceptOpts=()
	for a in "${archList[@]}"; do autoAcceptOpts+=("-A*.${a}.rpm"); done
fi

if grep -E -w 'rtk|kernel-rt' <<<"${builds[*]}"; then
	run "yum --setopt=strict=0 install @RT @NFV -y"
	for a in "${archList[@]}"; do autoAcceptOpts+=("-A*-rt-*.${a}.rpm"); done
elif grep -E -w '64k|kernel-64k' <<<"${builds[*]}"; then
	for a in "${archList[@]}"; do autoAcceptOpts+=("-A*-64k*.${a}.rpm"); done
fi

# Download packges
depthLevel=${DEPTH_LEVEL:-2}
buildcnt=${#builds[@]}
for build in "${builds[@]}"; do
	[[ "$build" = -* ]] && { continue; }

	if [[ "$build" = rtk || "$build" = 64k ]]; then
		let buildcnt--
		continue
	elif [[ "$build" = upk ]]; then
		run install_brew -
		KOJI=koji
		build=$($KOJI list-builds --pattern=kernel-?.*eln* --state=COMPLETE --after=$(date -d"now-32 days" +%F) --quiet |
			sort -Vr | awk '{print $1; exit}')
	elif [[ "$build" = lstk ]]; then
		run install_brew -
		KOJI=brew
		if [[ "$(rpm -E %rhel)" != %rhel && "$(uname -r)" = *eln* ]]; then
			_vr=$(yum provides kernel-core | awk -v RS= '/BaseOS/{print $NF}')
			read ver rel < <(echo "$_vr"|sed -r 's/^([0-9]+.[0-9]+.[0-9]+)-(.*)$/\1 \2/')
			_pattern="kernel-${ver}-${rel/*./*.}*"
		else
			read ver rel < <(rpm -q --qf '%{version} %{release}\n' kernel-$(uname -r))
			rel=${rel%.kpq*}
			_pattern="kernel-${ver}-${rel/*./*.}*"
		fi
		build=$($KOJI list-builds --pattern=$_pattern --state=COMPLETE  --quiet 2>/dev/null |
			sort -Vr | awk "\$1 ~ /-[-.0-9]+\.${rel/*./}[^.]*$/"'{print $1; exit}')
	elif [[ "$build" = latest-* ]]; then
		pkg=${build#latest-}
		run install_brew -
		read ver rel < <(rpm -q --qf '%{version} %{release}\n' kernel-$(uname -r))
		build=$($KOJI list-builds --pattern=$pkg-*-${rel/*./*.} --state=COMPLETE --after=$(date -d"now-1024 days" +%F)  --quiet 2>/dev/null |
			sort -Vr | awk '{print $1; exit}')
	fi

	if [[ "$build" =~ ^[0-9]+$ ]]; then
		run install_brew -
		if [[ "$KOJI" = koji ]]; then
			downloadBaseUrl=https://kojipkgs.fedoraproject.org
		fi
		taskid=${build}
		#wait the scratch build task finish
		while $KOJI taskinfo $taskid|grep -q '^State: open'; do echo "[$(date +%T) Info] build hasn't finished, wait"; sleep 5m; done

		run "$KOJI taskinfo -r $taskid > >(tee ${KOJI}_taskinfo.txt)"
		run "awk '/\\<($archPattern)\\.rpm/{print}' ${KOJI}_taskinfo.txt >buildArch.txt"
		run "cat buildArch.txt"
		_buildname=$(awk -v IGNORECASE=1 '/^build:/ {print $2}' ${KOJI}_taskinfo.txt)

		[ -z "$(< buildArch.txt)" ] && {
			echo "$prompt [Warn] rpm not found, treat the [$taskid] as build ID."
			buildid=$taskid
			run "$KOJI buildinfo $buildid > >(tee ${KOJI}_buildinfo.txt)"
			run "awk '/\\<($archPattern)\\.rpm/{print}' ${KOJI}_buildinfo.txt >buildArch.txt"
			run "cat buildArch.txt"
			_buildname=$(awk -v IGNORECASE=1 '/^build:/ {print $2}' ${KOJI}_buildinfo.txt)
		}

		[[ "$_buildname" != kernel-* ]] && {
			autoAcceptOpts=()
			for a in "${archList[@]}"; do autoAcceptOpts+=("-A*.${a}.rpm"); done
		}

		urllist=$(sed -r '/\/?mnt.redhat.(.*\.rpm)(|.*)$/s;;\1;' buildArch.txt)
		if [[ "$KOJI" = koji ]]; then
			urllist=$(sed -r '/\/?mnt.koji.(.*\.rpm)(|.*)$/s;;\1;' buildArch.txt)
		fi
		urllist=$(echo "$urllist" | rpmFilter "${autoRejectOpts[@]}" "${autoAcceptOpts[@]}" "${RejectOpts[@]}" "${AcceptOpts[@]}")
		for url in $urllist; do
			run "curl -O -L $downloadBaseUrl/$url" 0  "download-${url##*/}"
		done

		#try download rpms from brew download server
		[[ -z "$urllist" && "$KOJI" = brew ]] && {
			owner=$(awk '/^Owner:/{print $2}' ${KOJI}_taskinfo.txt)
			downloadServerUrl=$downloadBaseUrl/brewroot/scratch/$owner/task_$taskid
			is_available_url $downloadServerUrl && {
				finalUrl=$(curl -Ls -o /dev/null -w %{url_effective} $downloadServerUrl)
				which wget &>/dev/null || yum install -y wget
				download_rpms_from_url $finalUrl
				find */ -name '*.rpm' | xargs -i mv {} ./
			}
		}
	elif [[ "$build" =~ ^nfs: ]]; then
		nfsmp=/mnt/nfsmountpoint-$$
		mkdir -p $nfsmp
		nfsaddr=${build/nfs:/}
		nfsserver=${nfsaddr%:/*}
		exportdir=${nfsaddr#*:/}
		which mount.nfs &>/dev/null ||
			yum install -y nfs-utils
		run "mount $nfsserver:/ $nfsmp"
		for a in "${archList[@]}"; do
			ls $nfsmp/$exportdir/*.${a}.rpm &&
				run "cp -f $nfsmp/$exportdir/*.${a}.rpm ."
		done
		run "umount $nfsmp" -
	elif [[ "$build" =~ ^repo: || "$build" = *s3.upshift.redhat.com/DH-PROD-CKI/internal/*/*.?basearch ]]; then
		download_pkgs_from_repo ${build#repo:}
	elif [[ "$build" =~ ^(ftp|http|https):// ]]; then
		for url in $build; do
			if [[ $url = *.rpm ]]; then
				run "curl -O -L $url" 0  "download-${url##*/}"
			else
				which wget &>/dev/null || yum install -y wget
				download_rpms_from_url $url
				find */ -name '*.rpm' | xargs -i mv {} ./
			fi
		done
	else
		nbuild=$($KOJI list-builds --pattern=${build} --state=COMPLETE  --quiet 2>/dev/null | sort -Vr | awk '{print $1; exit}')
		if [[ -z "$nbuild" ]]; then
			nbuild=$($KOJI list-builds --pattern=${build}* --state=COMPLETE  --quiet 2>/dev/null | sort -Vr | awk '{print $1; exit}')
			[[ -n "$nbuild" ]] && build=$nbuild
		fi
		if [[ "$ONLY_DOWNLOAD" != yes && -z "$DEBUG_INFO_OPT" ]]; then
			curknvr=kernel-$(uname -r)
			if [[ "$build" = ${curknvr%.*} && "$FLAG" != debugkernel ]]; then
				report_result "kernel($build) has been installed" PASS
				let buildcnt--
				continue
			fi

			if rpm -q $build 2>/dev/null && [[ "$FLAG" != debugkernel ]]; then
				report_result "build($build) has been installed" PASS
				let buildcnt--
				continue
			fi
		fi

		run install_brew -
		buildname=$build
		[[ "$buildname" != kernel-* ]] && {
			autoAcceptOpts=()
			for a in "${archList[@]}"; do autoAcceptOpts+=("-A*.${a}.rpm"); done
		}
		urls=$(buildname2url $buildname)
		if [[ $? = 0 ]]; then
			which wget &>/dev/null || yum install -y wget
			for url in $urls; do
				download_rpms_from_url $url
				find */ -name '*.rpm' | xargs -i mv {} ./
			done
		else
			for a in "${archList[@]}"; do
				run "$KOJI download-build $DEBUG_INFO_OPT $buildname --arch=${a}" - ||
					run "koji download-build $DEBUG_INFO_OPT $buildname --arch=${a}" -
			done
		fi

		for rpmf in $RPMS; do
			if ! test -f $rpmf; then
				run "$KOJI download-build --rpm $rpmf" - ||
					run "koji download-build --rpm $rpmf" -
			fi
		done
	fi
done

# Install packages
run "echo build_count: $buildcnt"
run "ls -lh"

if [[ $buildcnt -gt 0 ]]; then
	run "ls -lh *.rpm"
	[ $? != 0 ] && {
		report_result download-rpms FAIL
		exit 1
	}
else
	INSTALL_TYPE=nothing
	if ! grep -E -w 'rtk|64k' <<<"${builds[*]}"; then
		exit 0
	fi
fi

[[ "$ONLY_DOWNLOAD" = yes ]] && {
	exit 0
}

#install possible dependencies
ls -1 *.rpm | grep -q ^kernel-rt && {
	run "yum --setopt=strict=0 install -y @RT @NFV" -
}

rpmfiles=$(ls *.rpm | rpmFilter "${autoRejectOpts[@]}" "${autoAcceptOpts[@]}" "${RejectOpts[@]}" "${AcceptOpts[@]}")

case $INSTALL_TYPE in
nothing)
	if grep -E -w 'rtk' <<<"${builds[*]}"; then
		run "yum install -y --nogpgcheck --setopt=keepcache=1 --skip-broken kernel-rt*" -
	elif grep -E -w '64k' <<<"${builds[*]}"; then
		run "yum install -y --nogpgcheck --setopt=keepcache=1 --skip-broken kernel-64k*" -
	fi
	;;
rpms)
	run "rpm -Uvh --force --nodeps $rpmfiles" -
	;;
yum)
	run "yum install -y --nogpgcheck --setopt=keepcache=1 $rpmfiles" -
	;;
rpm)
	for rpm in $rpmfiles; do run "rpm -Uvh --force --nodeps $rpm" -; done
	;;
*)
	run "yum install -y --nogpgcheck --setopt=keepcache=1 $rpmfiles" - ||
		run "rpm -Uvh --force --nodeps $rpmfiles" - ||
		for rpm in $rpmfiles; do run "rpm -Uvh --force --nodeps $rpm" -; done
esac

#mount /boot if not yet
mountpoint /boot || mount /boot

yum install -y grubby
run "grubby --default-kernel"
if ls --help|grep -q time:.birth; then
	lsOpt='--time=birth'
else
	touch $(rpm -qlp *.rpm | grep ^/boot) 2>/dev/null
fi
[[ "$FLAG" =~ debugkernel ]] && { kpat="(.?debug|\+debug)"; } || { kpat=$; }
if grep -E -w 'rtk' <<<"${builds[*]}"; then
	kernelpath=$(ls /boot/vmlinuz-*$(uname -m)* -t1 ${lsOpt:--u}|grep -E "\\+rt$kpat|\\.rt.*$kpat" | head -1)
elif grep -E -w '64k' <<<"${builds[*]}"; then
	kernelpath=$(ls /boot/vmlinuz-*$(uname -m)* -t1 ${lsOpt:--u}|grep -E "\\+64k$kpat|\\.rt.*$kpat" | head -1)
elif grep -E '(^| )kernel-' <<<"${builds[*]}"; then
	kernelpath=$(ls /boot/vmlinuz-*$(uname -m)* -t1 ${lsOpt:--u}|grep -E "$kpat" | head -1)
fi
if [[ -n "$kernelpath" ]]; then
	# If the target kernel behind the current kernel, kernel scripts may not be run normally.
	run "grubby --set-default=$kernelpath" || {
		if [[ $(ls *.$(arch).rpm | wc -l) -ne 0 ]]; then
			run "yum reinstall -y --nogpgcheck --setopt=keepcache=1 *.rpm" - ||
			  run "rpm -Uvh --force --nodeps *.rpm" - ||
			  for rpm in *.rpm; do run "rpm -Uvh --force --nodeps $rpm" -; done
		fi
	}
fi

_reboot=no
if ls *.$(arch).rpm 2>/dev/null|grep -E '^kernel-(redhat|rt-|64k-)?(debug-)?[0-9]'; then
	[[ "$KREBOOT" = yes ]] && _reboot=yes
fi
if grep -E -w 'rtk|64k' <<<"${builds[*]}"; then
	[[ "$KREBOOT" = yes ]] && _reboot=yes
fi
[[ $_reboot = yes ]] && reboot || exit 0
