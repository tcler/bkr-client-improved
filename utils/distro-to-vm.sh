#!/bin/bash
LANG=C

Distro=
Location=
VM_OS_VARIANT=
OVERWRITE=no
KSPath=
ksauto=
MacvtapMode=vepa
VMName=

Usage() {
	cat <<-EOF >&2
	Usage:
	 $0 <[-d] distroname> [-ks ks-file] [-l location] [-port vncport] [-osv variant] [-macvtap {vepa|bridge}] [-f|-force] [-vmname name] [-g|-genimage]
	 $0 <[-d] distroname> [-pkginstall <arg>]

	Example Internet:
	 $0 centos-5 -l http://vault.centos.org/5.11/os/x86_64/
	 $0 centos-6 -l http://mirror.centos.org/centos/6.10/os/x86_64/
	 $0 centos-7 -l http://mirror.centos.org/centos/7/os/x86_64/
	 $0 centos-8 -l http://mirror.centos.org/centos/8/BaseOS/x86_64/os/
	 $0 centos-8 -l http://mirror.centos.org/centos/8/BaseOS/x86_64/os/ -pkginstall ftp://url/path/x.rpm
	 $0 centos-8 -l http://mirror.centos.org/centos/8/BaseOS/x86_64/os/ -pkginstall ftp://url/path/

	Example Intranet:
	 $0 RHEL-6.10
	 $0 RHEL-7.7
	 $0 RHEL-8.1.0 -f
	 $0 RHEL-8.1.0-20191015.0 -pkginstall 23822847  # brew scratch build id
	 $0 RHEL-8.1.0-20191015.0 -pkginstall kernel-4.18.0-147.8.el8  # brew build name
	 $0 RHEL-8.1.0-20191015.0 -pkginstall \$(brew search build "kernel-*.elrdy" | sort -Vr | head -n1)


	Comment: you can get [-osv variant] info by using(now -osv option is unnecessary):
	 $ osinfo-query os  #RHEL-7 and later
	 $ virt-install --os-variant list  #RHEL-6
	EOF
}

_at=`getopt -o hd:l:fn:g \
	--long help \
	--long ks: \
	--long osv: \
	--long os-variant: \
	--long port: \
	--long force \
	--long macvtap: \
	--long vmname: \
	--long genimage \
	--long xzopt: \
	--long pkginstall: \
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
	-f|--force)    OVERWRITE="yes"; shift 1;;
	--macvtap)     MacvtapMode="$2"; shift 2;;
	-n|--vmname)   VMName="$2"; shift 2;;
	-g|--genimage) GenerateImage=yes; shift 1;;
	--xzopt)       XZ="$2"; shift 2;;
	--pkginstall)  PKGS="$2"; shift 2;;
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

[[ -z "$Distro" ]] && Distro=$1
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
	grep -q "^ $VM_OS_VARIANT " <<<"$osvariants" || VM_OS_VARIANT=${VM_OS_VARIANT/.*/-unknown}
	grep -q "^ $VM_OS_VARIANT " <<<"$osvariants" || VM_OS_VARIANT=${VM_OS_VARIANT/[0-9]*/-unknown}
	if grep -q "^ $VM_OS_VARIANT " <<<"$osvariants"; then
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

vmname=${Distro//./}
vmname=${vmname,,}
[[ -n "$VMName" ]] && vmname=${VMName}
[[ -z "$KSPath" ]] && {
	ksauto=/tmp/ks-$VM_OS_VARIANT-$$.cfg
	KSPath=$ksauto
	which ks-generator.sh &>/dev/null ||
		wget -N -q https://raw.githubusercontent.com/tcler/bkr-client-improved/master/utils/ks-generator.sh
	bash ks-generator.sh -d $Distro -url $Location >$KSPath

	[[ -n "$PKGS" ]] && {
		cat <<-END >>$KSPath
		wget -N -q https://raw.githubusercontent.com/tcler/bkr-client-improved/master/utils/pkginstall.sh
		bash pkginstall.sh $PKGS
		END
	}

	sed -i "/^%post/s;$;\ntest -f /etc/hostname \&\& echo ${vmname} >/etc/hostname || echo HOSTNAME=${vmname} >>/etc/sysconfig/network;" $KSPath
	[[ "$Distro" =~ (RHEL|centos)-?5 ]] && {
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
sudo yum install -y libvirt libvirt-client virt-install virt-viewer qemu-kvm expect nmap-ncat nc libguestfs-tools-c &>/dev/null

echo -e "{INFO} install libvirt-nss module ..."
sudo yum install -y libvirt-nss &>/dev/null
grep -q '^hosts:.*libvirt libvirt_guest' /etc/nsswitch.conf ||
	sed -i '/^hosts:/s/files /&libvirt libvirt_guest /' /etc/nsswitch.conf

echo -e "{INFO} creating VM by using location:\n  $Location"
virsh desc $vmname &>/dev/null && {
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

: <<COMM
virsh net-define --file <(
	cat <<-NET
	<network>
	  <name>subnet10</name>
	  <bridge name="virbr10" />
	  <forward mode="nat" >
	    <nat>
	      <port start='1024' end='65535'/>
	    </nat>
	  </forward>
	  <ip address="192.168.10.1" netmask="255.255.255.0" >
	    <dhcp>
	      <range start='192.168.10.2' end='192.168.10.254'/>
	    </dhcp>
	  </ip>
	</network>
	NET
)
virsh net-start subnet10
virsh net-autostart subnet10
COMM

VNCPORT=${VNCPORT:-7777}
while nc 127.0.0.1 ${VNCPORT} </dev/null &>/dev/null; do
	let VNCPORT++
done

[[ "$GenerateImage" = yes ]] && {
	sed -i '/^reboot$/s//poweroff/' ${KSPath}
	NOREBOOT=--noreboot
}
ksfile=${KSPath##*/}
virt-install --connect=qemu:///system --hvm --accelerate \
  --name $vmname \
  --location $Location \
  $OS_VARIANT_OPT \
  --memory 2048 \
  --vcpus 2 \
  --disk size=8 \
  --network network=default \
  --network type=direct,source=$(get_default_if notbr),source_mode=$MacvtapMode \
  --initrd-inject $KSPath \
  --extra-args="ks=file:/$ksfile console=tty0 console=ttyS0,115200n8" \
  --vnc --vnclisten 0.0.0.0 --vncport ${VNCPORT} $NOREBOOT &
installpid=$!
sleep 5s

while ! virsh desc $vmname &>/dev/null; do test -d /proc/$installpid || exit 1; sleep 1s; done
while true; do
	#clear -x
	printf '\33[H\33[2J'
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
			"error: internal error: character device console0 is not using a PTY" {
				send "\r"
				puts $expect_out(buffer)
				exit 7
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

if [[ "$GenerateImage" = yes ]]; then
	image=$(virsh dumpxml --domain $vmname | sed -n "/source file=/{s|^.*='||; s|'/>$||; p}")
	newimage=${image##*/}

	echo -e "\n{INFO} virt-sparsify image $image..."
	LIBGUESTFS_BACKEND=direct virt-sparsify ${image} ${newimage}

	echo -e "\n{INFO} compress image ..."
	time xz -z -f -T 0 ${XZ:--9} ${newimage}

	virsh undefine $vmname --remove-all-storage
else
	echo "{INFO} VNC port ${VNCPORT}"

	echo "{INFO} you can try login $vmname by:"
	echo -e "  $ vncviewer $HOSTNAME:$VNCPORT  #from remote"
	echo -e "  $ virsh console $vmname"
	echo -e "  $ ssh foo@$vmname  #password: redhat"
	read addr host < <(getent hosts $vmname)
	[[ -n "$addr" ]] && {
		echo -e "  $ ssh foo@$addr  #password: redhat"
	}
fi
