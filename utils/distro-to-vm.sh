#!/bin/bash
LANG=C

Distro=
Location=
KSPath=
VM_OS_VARIANT=

Usage() {
	cat <<-EOF >&2
	Usage:
	 $0 <-d distroname> <-osv variant> [-ks kickstart] [-l location] [-port vncport]

	Comment: you can get <-osv variant> info by using:
	 $ osinfo-query os  #RHEL-7 and later
	 $ virt-install --os-variant list  #RHEL-6
	EOF
}

_at=`getopt -o hd:l: \
	--long help \
	--long ks: \
	--long osv: \
	--long os-variant: \
	--long port: \
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	-d)        Distro=$2; shift 2;;
	-l)        Location=$2; shift 2;;
	--ks)      KSPath=$2; shift 2;;
	--osv|--os-variant) VM_OS_VARIANT="$2"; shift 2;;
	--port)    VNCPORT="$2"; shift 2;;
	--) shift; break;;
	esac
done

distro2location() {
	local distro=$1
	local arch=${2:-x86_64}
	local variant=${3:-Server}

	which bkr &>/dev/null &&
		distrotrees=$(bkr distro-trees-list --name "$distro" --arch "$arch")
	[[ -z "$distrotrees" ]] && {
		which distro-compose &>/dev/null ||
			wget -N -q https://raw.githubusercontent.com/tcler/bkr-client-improved/master/utils/distro-compose
		distrotrees=$(bash distro-compose -d "$distro" --distrotrees)
	}
	urls=$(echo "$distrotrees" | awk '/https?:.*\/'"(${variant}|BaseOS)\/${arch}"'\//{print $3}' | sort -u)

	which fastesturl.sh &>/dev/null ||
		wget -N -q https://raw.githubusercontent.com/tcler/bkr-client-improved/master/utils/fastesturl.sh
	bash fastesturl.sh $urls
}

[[ -z "$Distro" || -z "$VM_OS_VARIANT" ]] && {
	Usage
	exit 1
}

echo "{INFO} verify os-variant ..."
osvariants=$(virt-install --os-variant list 2>/dev/null) ||
	osvariants=$(osinfo-query os 2>/dev/null)
[[ -n "$osvariants" ]] && {
	grep -q -w "$VM_OS_VARIANT" <<<"$osvariants" || {
		echo -e "{WARN} Unknown OS variant '$VM_OS_VARIANT'."
		echo -e "unkown OS variant, you could find accepted os variants from here(Short ID):\n\n$osvariants"|less
		exit 1
	}
}

[[ -z "$Location" ]] && {
	echo "{INFO} trying to get distro location according distro name($Distro) ..."
	Location=$(distro2location $Distro)

	[[ -z "$Location" ]] && {
		echo "{WARN} can not get distro location. please check if '$Distro' is valid distro" >&2
		exit
	}
}

[[ -z "$KSPath" ]] && {
	KSPath=/tmp/ks-$VM_OS_VARIANT-$$.cfg
	which ks-generator.sh &>/dev/null ||
		wget -N -q https://raw.githubusercontent.com/tcler/bkr-client-improved/master/utils/ks-generator.sh
	bash ks-generator.sh -d $Distro -url $Location >$KSPath
}

echo -e "{INFO} install libvirt service and related packages ..."
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum install -y libvirt libvirt-client virt-install virt-viewer qemu-kvm genisoimage libguestfs-tools \
libguestfs-tools-c openldap-clients dos2unix unix2dos glibc-common libguestfs-winsupport unix2dos

echo -e "{INFO} creating VM by using location:\n  $Location"
vmname=vm-$Distro
[[ "${OVERWRITE:-yes}" = "yes" ]] && {
        virsh undefine $vmname
        virsh destroy $vmname
}
service libvirtd restart
service virtlogd restart

ksfile=${KSPath##*/}
virt-install \
  --name $vmname \
  --location $Location \
  --os-variant $VM_OS_VARIANT \
  --memory 2048 \
  --vcpus 2 \
  --disk size=8 \
  --initrd-inject $KSPath \
  --extra-args="ks=file:/$ksfile console=tty0 console=ttyS0,115200n8" \
  --vnc --vnclisten 0.0.0.0 --vncport ${VNCPORT:-7777}
