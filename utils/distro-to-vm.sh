#!/bin/bash

Distro=
Location=
KSPath=
VM_OS_VARIANT=

Usage() {
	cat <<-EOF >&2
	Usage:
	 $0 <-d distroname> <-ks kickstart> <-osv variant> [-l location]

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
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	-d)        Distro=$2; shift 2;;
	-l)        Location=$2; shift 2;;
	--ks)      KSPath=$2; shift 2;;
	--osv|--os-variant) VM_OS_VARIANT="$2"; shift 2;;
	--) shift; break;;
	esac
done

distro2location() {
	local distro=$1
	local arch=${2:-x86_64}
	local variant=${3:-Server}

	distrotrees=$(bkr distro-trees-list --name "$distro" --arch "$arch")
	[[ -z "$distrotrees" ]] && {
		which distro-compose &>/dev/null ||
			wget https://raw.githubusercontent.com/tcler/bkr-client-improved/master/utils/distro-compose
		distrotrees=$(bash distro-compose -d "$distro" --distrotrees)
	}
	urls=$(echo "$distrotrees" | awk '/https?:.*\/'"(${variant}|BaseOS)\/${arch}"'\//{print $3}' | sort -u)

	which fastesturl.sh &>/dev/null ||
		wget https://raw.githubusercontent.com/tcler/bkr-client-improved/master/utils/fastesturl.sh
	bash fastesturl.sh $urls
}

[[ -z "$Distro" || -z "$VM_OS_VARIANT" || -z "$KSPath" ]] && {
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

echo -e "{INFO} creating VM by using location:\n  $Location"
exit

ksfile=${KSPath##*/}

virt-install \
  --name vm-$Distro \
  --location $Location \
  --os-variant $VM_OS_VARIANT \
  --memory 2048 \
  --vcpus 2 \
  --disk size=8 \
  --initrd-inject $KSPath \
  --extra-args="ks=file:/$ksfile console=tty0 console=ttyS0,115200n8"
