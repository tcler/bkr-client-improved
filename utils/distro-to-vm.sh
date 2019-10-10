#!/bin/bash
LANG=C

Distro=
Location=
VM_OS_VARIANT=
OVERWRITE=no
KSPath=
ksauto=
MacvtapMode=vepa

Usage() {
	cat <<-EOF >&2
	Usage:
	 $0 <-d distroname> [-osv variant] [-ks kickstart] [-l location] [-port vncport] [-force] [-macvtap {vepa|bridge}]

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
	--long force \
	--long macvtap: \
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
	--force)   OVERWRITE="yes"; shift 1;;
	--macvtap)   MacvtapMode="$2"; shift 2;;
	--) shift; break;;
	esac
done

distro2location() {
	local distro=$1
	local variant=${2:-Server}
	local arch=$(arch)

	which bkr &>/dev/null &&
		distrotrees=$(bkr distro-trees-list --name "$distro" --arch "$arch")
	[[ -z "$distrotrees" ]] && {
		which distro-compose &>/dev/null ||
			wget -N -q https://raw.githubusercontent.com/tcler/bkr-client-improved/master/utils/distro-compose
		distrotrees=$(bash distro-compose -d "$distro" --distrotrees)
	}
	urls=$(echo "$distrotrees" | awk '/https?:.*\/'"(${variant}|BaseOS)\/${arch}"'\//{print $3}' | sort -u)
	[[ "$distro" = RHEL5* ]] && {
		pattern=${distro//-/.}
		pattern=${pattern/5/-?5}
		urls=$(echo "$distrotrees" | awk '/https?:.*\/'"${pattern}\/${arch}"'\//{print $3}' | sort -u)
	}

	which fastesturl.sh &>/dev/null ||
		wget -N -q https://raw.githubusercontent.com/tcler/bkr-client-improved/master/utils/fastesturl.sh
	bash fastesturl.sh $urls
}

[[ -z "$Distro" ]] && {
	Usage
	exit 1
}

echo "{INFO} guess/verify os-variant ..."
#Speculate the appropriate VM_OS_VARIANT according distro name
[[ -z "$VM_OS_VARIANT" ]] && {
	VM_OS_VARIANT=${Distro/-/}
	VM_OS_VARIANT=${VM_OS_VARIANT%%-*}
	VM_OS_VARIANT=${VM_OS_VARIANT,,}
}
osvariants=$(virt-install --os-variant list 2>/dev/null) ||
	osvariants=$(osinfo-query os 2>/dev/null)
[[ -n "$osvariants" ]] && {
	grep -q "^ $VM_OS_VARIANT" <<<"$osvariants" || VM_OS_VARIANT=${VM_OS_VARIANT/.*/-unknown}
	grep -q "^ $VM_OS_VARIANT" <<<"$osvariants" || VM_OS_VARIANT=${VM_OS_VARIANT/[0-9]*/-unknown}
	if grep -q "^ $VM_OS_VARIANT" <<<"$osvariants"; then
		OS_VARIANT_OPT=--os-variant=$VM_OS_VARIANT
	fi
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
	ksauto=/tmp/ks-$VM_OS_VARIANT-$$.cfg
	KSPath=$ksauto
	which ks-generator.sh &>/dev/null ||
		wget -N -q https://raw.githubusercontent.com/tcler/bkr-client-improved/master/utils/ks-generator.sh
	bash ks-generator.sh -d $Distro -url $Location >$KSPath

	[[ "$Distro" = RHEL5* ]] && {
		ex -s $KSPath <<-EOF
		/%packages/,/%end/ d
		$ put
		$ d
		w
		EOF
	}
}

echo -e "{INFO} install libvirt service and related packages ..."
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &>/dev/null
sudo yum install -y libvirt libvirt-client virt-install virt-viewer qemu-kvm libguestfs-tools expect &>/dev/null

echo -e "{INFO} install libvirt-nss module ..."
sudo yum install -y libvirt-nss &>/dev/null
grep -q '^hosts:.*libvirt libvirt_guest' /etc/nsswitch.conf ||
	sed -i '/^hosts:/s/files /&libvirt libvirt_guest /' /etc/nsswitch.conf

echo -e "{INFO} creating VM by using location:\n  $Location"
vmname=vm-${Distro//./}
virsh desc $vmname 2>/dev/null && {
	if [[ "${OVERWRITE}" = "yes" ]]; then
		file=$(virsh dumpxml --domain $vmname | sed -n "/source file=/{s|^.*='||; s|'/>$||; p}")
		virsh destroy $vmname
		virsh undefine $vmname --remove-all-storage
		[[ -f "$file" ]] && \rm "$file"
	else
		echo "{INFO} VM $vmname has been there, if you want overwrite please use --force option"
		[[ -n "$ksauto" ]] && \rm -f $ksauto
		exit
	fi
}

service libvirtd start
service virtlogd start

is_bridge() {
	local ifname=$1
	[[ -z "$ifname" ]] && return 1
	ip -d a s $ifname | grep -qw bridge
}
get_default_if() {
	local notbr=$1
	local iface=

	iface=$(ip route get 1 | awk '/^[0-9]/{print $5}')
	if [[ -n "$notbr" ]] && is_bridge $iface; then
		# ls /sys/class/net/$iface/brif
		if command -v brctl; then
			brctl show $iface | awk 'NR==2 {print $4}'
		else
			ip link show type bridge_slave | awk -F'[ :]+' '/master '$iface' state UP/{print $2}' | head -n1
		fi
		return 0
	fi
	echo $iface
}

virsh net-create --file <(
	cat <<-NET
	<network>
	  <name>nnetwork</name>
	  <bridge name="virbr1" />
	  <forward mode="nat" >
	    <nat>
	      <port start='1024' end='65535'/>
	    </nat>
	  </forward>
	  <ip address="192.168.100.1" netmask="255.255.255.0" >
	    <dhcp>
	      <range start='192.168.100.2' end='192.168.100.254'/>
	    </dhcp>
	  </ip>
	</network>
	NET)

ksfile=${KSPath##*/}
virt-install --connect=qemu:///system --hvm --accelerate \
  --name $vmname \
  --location $Location \
  $OS_VARIANT_OPT \
  --memory 2048 \
  --vcpus 2 \
  --disk size=8 \
  --network network=nnetwork \
  --network network=default \
  --network type=direct,source=$(get_default_if notbr),source_mode=$MacvtapMode \
  --initrd-inject $KSPath \
  --extra-args="ks=file:/$ksfile console=tty0 console=ttyS0,115200n8" \
  --vnc --vnclisten 0.0.0.0 --vncport ${VNCPORT:-7777} &
installpid=$!
sleep 5s

while true; do
	clear
	expect -c '
		set timeout -1
		spawn virsh console '"$vmname"'
		expect {
			"error: Disconnected from qemu:///system due to end of file*" {
				send "\r"
				puts $expect_out(buffer)
				exit 5
			}
			"error: The domain is not running" {
				send "\r"
				puts $expect_out(buffer)
				exit 6
			}
			"* login:" {
				send "\r"
				exit 0
			}
		}
	' && break
	test -d /proc/$installpid || break
	sleep 2
done

# waiting install finish ...
echo -e "{INFO} waiting install finish ..."
while test -d /proc/$installpid; do sleep 5; done

[[ -n "$ksauto" ]] && \rm -f $ksauto

read addr host < <(getent hosts $vmname)
echo "{INFO} $vmname's address is $addr, try: ssh $addr"
