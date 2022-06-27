#!/bin/bash
# Description: to install brew scratch build or 3rd party pkgs
# Author: Jianhong Yin <jiyin@redhat.com>

LANG=C
baseDownloadUrl=https://raw.githubusercontent.com/tcler/bkr-client-improved/master

is_available_url() {
        local _url=$1
        curl --connect-timeout 8 -m 16 --output /dev/null --silent --head --fail $_url &>/dev/null
}
is_intranet() {
	local iurl=http://download.devel.redhat.com
	is_available_url $iurl
}

[[ function = "$(type -t report_result)" ]] || report_result() {  echo "$@"; }

P=${0##*/}
KREBOOT=yes
INSTALL_TYPE=undefine

retcode=0
prompt="[brew-install]"
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
	 $P <[brew_scratch_build_id] | [lstk|lstdtk|upk|brew_build_name] | [url]>  [-debugk] [-noreboot] [-depthLevel=\${N:-2}] [-debuginfo] [-onlydebuginfo] [-onlydownload] [-arch=\$arch]

	Example:
	 $P 23822847  # brew scratch build id
	 $P kernel-4.18.0-147.8.el8    # brew build name
	 $P [ftp|http]://url/xyz.rpm   # install xyz.rpm
	 $P nfs:server/nfsshare        # install all rpms in nfsshare
	 $P repo:rname,url             # install all rpms in repo rname
	 $P lstk                       # install latest release kernel
	 $P lstk -debuginfo            # install latest release kernel and it's -debuginfo package
	 $P lstk -debugk               # install latest release debug kernel
	 $P lstdtk                     # install latest dt(devel/test) kernel
	 $P upk                        # install latest upstream kernel
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

is_intranet && {
	Intranet=yes
	baseDownloadUrl=http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved
}

install_brew() {
	which brew &>/dev/null || {
		which brewkoji_install.sh &>/dev/null || {
			_url=$baseDownloadUrl/utils/brewkoji_install.sh
			mkdir -p ~/bin && curl -o ~/bin/brewkoji_install.sh -s -L $_url
			chmod +x ~/bin/brewkoji_install.sh
		}
		PATH=~/bin:$PATH brewkoji_install.sh >/dev/null || {
			echo "{WARN} install brewkoji failed" >&2
			exit 1
		}
	}
}

download_pkgs_from_repo() {
	local repopath=$1
	local reponame=
	local url=
	local rpms=

	if [[ "$repopath" =~ ^(ftp|http|https):// ]]; then
		repopath=repo-$RANDOM,$repopath
	fi

	read reponame url <<< "${repopath/,/ }"

	verx=$(rpm -E %rhel)
	if [[ "$verx" -le 7 ]]; then
		yum install -y yum-utils &>/dev/null
		cat <<-REPO >/etc/yum.repos.d/${reponame}.repo
		[$reponame]
		name=$reponame
		baseurl=$url
		enabled=1
		gpgcheck=0
		skip_if_unavailable=1
		REPO
	fi

	: <<-COMM
	#install dependency
	yum install -y perl python3 binutils iproute-tc nmap-ncat perf

	#get package list from repo
	if [[ "$verx" -le 7 ]]; then
		rpms=$(repoquery --repoid=$reponame -a)
	else
		rpms=$(yum  --disablerepo=* --repofrompath=$repopath  rq $reponame \* 2>/dev/null)
	fi
	if [[ -z "$rpms" ]]; then
		echo "{WARN} get rpms from repo($reponame) fail" >&2
		return 1
	fi

	#download package list
	if [[ "$verx" -le 7 ]]; then
		yum --disablerepo=* repo-pkgs $reponame install $rpms \
			--downloadonly --skip-broken -y --nogpgcheck --downloaddir=.
	else
		yum --disablerepo=* --repofrompath=$repopath repo-pkgs $reponame install $rpms \
			--downloadonly --skip-broken -y --nogpgcheck --destdir=.
	fi
	COMM

	if [[ "$verx" -le 7 ]]; then
		urls=$(yumdownloader --url --disablerepo=* --enablerepo=$reponame \*)
	else
		urls=$(yum download --url --disablerepo=* --repofrompath=$repopath \*)
	fi

	for url in $urls; do
		wget $url 2>/dev/null
	done
}

# parse options
builds=()
for arg; do
	case "$arg" in
	-debuginfo)      DEBUG_INFO_OPT=--debuginfo;;
	-onlydebuginfo)  DEBUG_INFO_OPT=--debuginfo; ONLY_DEBUG_INFO=yes; KREBOOT=no;;
	-onlydownload)   ONLY_DOWNLOAD=yes;;
	-debug|-debugk*) FLAG=debugkernel;;
	-noreboot*)      KREBOOT=no;;
	-depthLevel=*)   depthLevel=${arg/*=/};;
	-rpms*)          INSTALL_TYPE=rpms;;
	-yum*)           INSTALL_TYPE=yum;;
	-rpm)            INSTALL_TYPE=rpm;;
	-arch=*)         _ARCH=${arg/*=/};;
	-h)              Usage; exit;;
	-*)              echo "{WARN} unkown option '${arg}'";;
	*)
			builds+=($arg)
		;;
	esac
done

# fix ssl certificate verify failed
curl -s https://password.corp.redhat.com/RH-IT-Root-CA.crt -o /etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt
curl -s https://password.corp.redhat.com/legacy.crt -o /etc/pki/ca-trust/source/anchors/legacy.crt
update-ca-trust

if [[ "${#builds[@]}" = 0 ]]; then
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
wgetOpts=$(for a in "${archList[@]}"; do echo -n " -A.${a}.rpm"; done)

# Download packges
depthLevel=${DEPTH_LEVEL:-2}
buildcnt=${#builds[@]}
for build in "${builds[@]}"; do
	[[ "$build" = -* ]] && { continue; }

	[[ "$build" = upk ]] && {
		run install_brew -
		build=$(koji list-builds --pattern=kernel-?.*eln* --state=COMPLETE --after=$(date -d"now-32 days" +%F) --quiet | sort -Vr | awk '{print $1; exit}')
	}
	[[ "$build" = lstk ]] && {
		run install_brew -
		read ver rel < <(rpm -q --qf '%{version} %{release}\n' kernel-$(uname -r))
		build=$(brew list-builds --pattern=kernel-${ver/.*/.*}-${rel/*./*.}* --state=COMPLETE  --quiet 2>/dev/null | sort -Vr | awk '{print $1; exit}')
	}
	[[ "$build" = lstdtk ]] && {
		run install_brew -
		read ver rel < <(rpm -q --qf '%{version} %{release}\n' kernel-$(uname -r))
		build=$(brew list-builds --pattern=kernel-${ver/.*/.*}-${rel/*./*.}.dt* --state=COMPLETE  --quiet 2>/dev/null | sort -Vr | awk '{print $1; exit}')
	}
	[[ "$build" = latest-* ]] && {
		pkg=${build#latest-}
		run install_brew -
		read ver rel < <(rpm -q --qf '%{version} %{release}\n' kernel-$(uname -r))
		build=$(brew list-builds --pattern=$pkg-*-${rel/*./*.} --state=COMPLETE --after=$(date -d"now-1024 days" +%F)  --quiet 2>/dev/null | sort -Vr | awk '{print $1; exit}')
	}

	if [[ "$build" =~ ^[0-9]+$ ]]; then
		run install_brew -
		taskid=${build}
		#wait the scratch build finish
		while brew taskinfo $taskid|grep -q '^State: open'; do echo "[$(date +%T) Info] build hasn't finished, wait"; sleep 5m; done

		run "brew taskinfo -r $taskid > >(tee brew_taskinfo.txt)"
		run "awk '/\\<($archPattern)\\.rpm/{print}' brew_taskinfo.txt >buildArch.txt"
		run "cat buildArch.txt"

		: <<-'COMM'
		[ -z "$(< buildArch.txt)" ] && {
			echo "$prompt [Warn] rpm not found, treat the [$taskid] as build ID."
			buildid=$taskid
			run "brew buildinfo $buildid > >(tee brew_buildinfo.txt)"
			run "awk '/\\<($archPattern)\\.rpm/{print}' brew_buildinfo.txt >buildArch.txt"
			run "cat buildArch.txt"
		}
		COMM

		urllist=$(sed '/mnt.redhat..*rpm$/s; */mnt/redhat/;;' buildArch.txt)
		for url in $urllist; do
			run "curl -O -L http://download.devel.redhat.com/$url" 0  "download-${url##*/}"
		done

		#try download rpms from brew download server
		[[ -z "$urllist" ]] && {
			owner=$(awk '/^Owner:/{print $2}' brew_taskinfo.txt)
			downloadServerUrl=http://download.devel.redhat.com/brewroot/scratch/$owner/task_$taskid
			is_available_url $downloadServerUrl && {
				finalUrl=$(curl -Ls -o /dev/null -w %{url_effective} $downloadServerUrl)
				which wget &>/dev/null || yum install -y wget
				run "wget -r -l$depthLevel --no-parent $wgetOpts --progress=dot:mega $finalUrl" 0  "download-${finalUrl##*/}"
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
	elif [[ "$build" =~ ^repo: || "$build" = *//s3.upshift.redhat.com/* ]]; then
		download_pkgs_from_repo ${build#repo:}
	elif [[ "$build" =~ ^(ftp|http|https):// ]]; then
		for url in $build; do
			if [[ $url = *.rpm ]]; then
				run "curl -O -L $url" 0  "download-${url##*/}"
			else
				which wget &>/dev/null || yum install -y wget
				run "wget -r -l$depthLevel --no-parent $wgetOpts --progress=dot:mega $url" 0  "download-${url##*/}"
				find */ -name '*.rpm' | xargs -i mv {} ./
			fi
		done
	else
		if [[ "$ONLY_DOWNLOAD" != yes ]]; then
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
		for a in "${archList[@]}"; do
			run "brew download-build $DEBUG_INFO_OPT $buildname --arch=${a}" - ||
				run "koji download-build $DEBUG_INFO_OPT $buildname --arch=${a}" -
		done

		for rpmf in $RPMS; do
			if ! test -f $rpmf; then
				run "brew download-build --rpm $rpmf" - ||
					run "koji download-build --rpm $rpmf" -
			fi
		done
	fi
done

# Install packages
run "ls -lh"
if [[ $buildcnt -gt 0 ]]; then
	run "ls -lh *.rpm"
	[ $? != 0 ] && {
		report_result download-rpms FAIL
		exit 1
	}
else
	exit 0
fi

[[ "$ONLY_DOWNLOAD" = yes ]] && {
	exit 0
}

#install possible dependencies
ls -1 *.rpm | grep -q ^kernel-rt && {
	run "yum install -y @RT" -
}

for rpm in *.rpm; do
	[[ "$ONLY_DEBUG_INFO" = yes && $rpm != *-debuginfo-* ]] && {
		rm -f $rpm
		continue
	}
done

case $INSTALL_TYPE in
rpms)
	run "rpm -Uvh --force --nodeps *.rpm" -
	;;
yum)
	run "yum install -y --nogpgcheck --setopt=keepcache=1 *.rpm" -
	;;
rpm)
	for rpm in *.rpm; do run "rpm -Uvh --force --nodeps $rpm" -; done
	;;
*)
	run "yum install -y --nogpgcheck --setopt=keepcache=1 *.rpm" - ||
		run "rpm -Uvh --force --nodeps *.rpm" -
esac

# if include debug in FLAG
[[ "$FLAG" =~ debugkernel ]] && {
	if [ -x /sbin/grubby -o -x /usr/sbin/grubby ]; then
		VRA=$(rpm -qp --qf '%{version}-%{release}.%{arch}' $(ls kernel-debug*rpm | head -1))
		run "grubby --set-default /boot/vmlinuz-${VRA}*debug"
	elif [ -x /usr/sbin/grub2-set-default ]; then
		run "grub2-set-default $(grep ^menuentry /boot/grub2/grub.cfg | cut -f 2 -d \' | nl -v 0 | awk '/\.debug)/{print $1}')"
	elif [ -x /usr/sbin/grub-set-default ]; then
		run "grub-set-default $(grep '^[[:space:]]*kernel' /boot/grub/grub.conf | nl -v 0 | awk '/\.debug /{print $1}')"
	fi
}

if ls *.$(arch).rpm|egrep '^kernel-(rt-)?[0-9]'; then
	[[ "$KREBOOT" = yes ]] && reboot
fi
