#!/bin/bash
# Description: to install brew scratch build or 3rd party pkgs
# Author: Jianhong Yin <jiyin@redhat.com>

baseDownloadUrl=https://raw.githubusercontent.com/tcler/bkr-client-improved/master

is_intranet() {
	local iurl=http://download.devel.redhat.com
	curl --connect-timeout 5 -m 10 --output /dev/null --silent --head --fail $iurl &>/dev/null
}

is_intranet && {
	Intranet=yes
	baseDownloadUrl=http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved
}

# install brew
which brew &>/dev/null || {
	which brewkoji_install.sh &>/dev/null || {
		_url=$baseDownloadUrl/utils/brewkoji_install.sh
		mkdir -p ~/bin && wget -O ~/bin/brewkoji_install.sh -N -q $_url
		chmod +x ~/bin/brewkoji_install.sh
	}
	PATH=~/bin:$PATH brewkoji_install.sh >/dev/null || {
		echo "{WARN} install brewkoji failed" >&2
		exit 1
	}
}

[[ function = "$(type -t report_result)" ]] || report_result() { :; }

P=${0##*/}
KREBOOT=yes
retcode=0
res=PASS
prompt="[pkg-install]"
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
	 $P <[brew_scratch_build_id] | [lstk|upk|brew_build_name] | [url]>  [-debug] [-noreboot]

	Example:
	 $P 23822847  # brew scratch build id
	 $P kernel-4.18.0-147.8.el8  # brew build name
	 $P [ftp|http]://url/xyz.rpm # install xyz.rpm
	 $P [ftp|http]://url/path/   # install all rpms in url/path
	 $P nfs:server/nfsshare      # install all rpms in nfsshare
	 $P lstk                     # install latest release kernel
	 $P upk                      # install latest upstream kernel
EOF
}

# Install scratch build package
[ -z "$*" ] && {
	Usage >&2
	exit
}

# Download packges
cnt=0
for build; do
	[[ "$build" = -debug* ]] && { FLAG=debug; continue; }
	[[ "$build" = -noreboot* ]] && { KREBOOT=no; continue; }
	[[ "$build" = -h ]] && { Usage; exit; }
	[[ "$build" = -* ]] && { continue; }

	[[ "$build" = upk ]] && {
		build=$(brew search build "kernel-*.elrdy" | sort -Vr | head -n1)
	}
	[[ "$build" = lstk ]] && {
		read ver rel < <(rpm -q --qf '%{version} %{release}\n' kernel-$(uname -r))
		build=$(brew search build kernel-$ver-${rel/*./*.} | sort -Vr | head -1)
	}

	let cnt++
	if [[ "$build" =~ ^[0-9]+(:.*)?$ ]]; then
		read taskid FLAG <<<${build/:/ }
		#wait the scratch build finish
		while brew taskinfo $taskid|grep -q '^State: open'; do echo "[$(date +%T) Info] build hasn't finished, wait"; sleep 5m; done

		run "brew taskinfo -r $taskid > >(tee brew_buildinfo.txt)"
		run "awk '/\\<($(arch)|noarch)\\.rpm/{print}' brew_buildinfo.txt >buildArch.txt"
		run "cat buildArch.txt"
		[ -z "$(< buildArch.txt)" ] && {
			echo "$prompt [Warn] rpm not found, treat the [$taskid] as build ID."
			buildid=$taskid
			run "brew buildinfo $buildid > >(tee brew_buildinfo.txt)"
			run "awk '/\\<($(arch)|noarch)\\.rpm/{print}' brew_buildinfo.txt >buildArch.txt"
			run "cat buildArch.txt"
		}
		urllist=$(sed '/mnt.redhat..*rpm$/s; */mnt/redhat/;;' buildArch.txt)
		for url in $urllist; do
			run "wget --progress=dot:mega http://download.devel.redhat.com/$url" 0  "download-${url##*/}"
		done
	elif [[ "$build" =~ ^nfs: ]]; then
		nfsmp=/mnt/nfsmountpoint-$$
		mkdir -p $nfsmp
		nfsaddr=${build/nfs:/}
		nfsserver=${nfsaddr%:/*}
		exportdir=${nfsaddr#*:/}
		run "mount $nfsserver:/ $nfsmp"
		ls $nfsmp/$exportdir/*.noarch.rpm &&
			run "cp -f $nfsmp/$exportdir/*.noarch.rpm ."
		ls $nfsmp/$exportdir/*.$(arch).rpm &&
			run "cp -f $nfsmp/$exportdir/*.$(arch).rpm ."
		run "umount $nfsmp" -
	elif [[ "$build" =~ ^(ftp|http|https):// ]]; then
		for url in $build; do
			if [[ $url = *.rpm ]]; then
				run "wget --progress=dot:mega $url" 0  "download-${url##*/}"
			else
				run "wget -r -l1 --no-parent -A.rpm --progress=dot:mega $url" 0  "download-${url##*/}"
				find */ -name '*.rpm' | xargs -i mv {} ./
			fi
		done
	else
		buildname=$build
		brew download-build $buildname --arch=noarch
		brew download-build $buildname --arch=$(arch)
	fi
done

[ "$cnt" = 0 ] && {
	Usage >&2
	exit
}

# Install packages
run "ls -lh"
run "rpm -Uvh --force --nodeps *.rpm"
[ $? != 0 ] && {
	report_result rpm-install FAIL
	exit 1
}

[[ "$retcode" != 0 ]] && res=FAIL
report_result install $res

# if include debug in FLAG
[[ "$FLAG" =~ debug ]] && {
	if [ -x /sbin/grubby -o -x /usr/sbin/grubby ]; then
		VRA=$(rpm -qp --qf '%{version}-%{release}.%{arch}' $(ls kernel-debug*rpm | head -1))
		grubby --set-default /boot/vmlinuz-${VRA}*debug
	elif [ -x /usr/sbin/grub2-set-default ]; then
		grub2-set-default $(grep ^menuentry /boot/grub2/grub.cfg | cut -f 2 -d \' | nl -v 0 | awk '/\.debug)/{print $1}')
	elif [ -x /usr/sbin/grub-set-default ]; then
		grub-set-default $(grep '^[[:space:]]*kernel' /boot/grub/grub.conf | nl -v 0 | awk '/\.debug /{print $1}')
	fi
}

if ls *.rpm|grep ^kernel-; then
	[[ "$KREBOOT" = yes ]] && reboot
fi
