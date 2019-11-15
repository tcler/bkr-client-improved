#!/bin/bash
# author: yin-jianhong@163.com

[[ $(id -u) != 0 ]] && {
	echo -e "{Warn} configure kdump need root permission, try:\n  sudo $0 ..." >&2
	exec sudo $0 "$@"
}

#phase0: check/install kexec-tools
#----------------------------------
rpm -q kexec-tools || yum install -y kexec-tools
echo

#phase1: show/fix image type
#----------------------------------
grep ^KDUMP_IMG= /etc/sysconfig/kdump
echo

#phase2: reserve memory
#----------------------------------
kver=$(uname -r|awk -F. '{print $1}')
if [[ $kver -ge 3 ]]; then
	val="1G-2G:128M,2G-4G:384M,4G-16G:512M,16G-64G:1G,64G-128G:2G,128G-:4G"
	val="auto"
else
	echo "{WARN} don't support kernel older then kernel-3"
	exit 1
fi

echo grubby --args="crashkernel=${val}" --update-kernel="$(/sbin/grubby --default-kernel)"
grubby --args="crashkernel=${val}" --update-kernel="$(/sbin/grubby --default-kernel)"

# hack /usr/bin/kdumpctl: add 'chmod a+r corefile'
sed 's;mv $coredir/vmcore-incomplete $coredir/vmcore;&\nchmod a+r $coredir/vmcore;' /usr/bin/kdumpctl -i

#phase3: enable kdump and reboot
#----------------------------------
systemctl enable kdump.service
[[ "$1" = reboot ]] && reboot
