#!/bin/bash
LANG=C
PATH=~/bin:$PATH 

PROG=${0##*/}
Intranet=no
Distro=
Location=
Imageurl=
VM_OS_VARIANT=
OVERWRITE=no
KSPath=
ksauto=
MacvtapMode=vepa
MacvtapMode=bridge
VMName=
InstallType=import
ImagePath=~/myimages
VMPath=~/VMs
RuntimeTmp=/tmp/distro-to-vm-$$
baseDownloadUrl=https://raw.githubusercontent.com/tcler/bkr-client-improved/master

Cleanup() {
	cd ~
	#echo "{DEBUG} Removing $RuntimeTmp"
	rm -rf $RuntimeTmp
	exit
}

enable_libvirt() {
	local pkglist="libvirt libvirt-client virt-install virt-viewer qemu-kvm expect nmap-ncat libguestfs-tools-c libvirt-nss dialog"

	echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ enable libvirt start ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo -e "{INFO} checking libvirtd service and related packages ..."
	rpm -q $pkglist || {
		echo -e "{*INFO*} you have not install all dependencies package, trying sudo yum install ..."
		sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
		sudo yum install -y $pkglist
	}

	#echo -e "{INFO} configure libvirt-nss ..."
	grep -q '^hosts:.*libvirt libvirt_guest' /etc/nsswitch.conf || {
		echo -e "{*INFO*} you have not configure /etc/nsswitch.conf, trying sudo sed ..."
		sudo sed -ri '/^hosts:/s/files /&libvirt libvirt_guest /' /etc/nsswitch.conf
	}

	sudouser=${SUDO_USER:-$(whoami)}
	eval sudouserhome=~$sudouser
	echo -e "{INFO} checking if ${sudouser} has joined group libvirt ..."
	[[ $(id -u) != 0 ]] && id -Gn | egrep -q -w libvirt || {
		echo -e "{*INFO*} run: sudo usermod -a -G libvirt $sudouser ..."
		sudo usermod -a -G libvirt $sudouser
	}

	virtdconf=/etc/libvirt/libvirtd.conf
	pvirtconf=$sudouserhome/.config/libvirt/libvirt.conf
	echo -e "{INFO} checking if UNIX domain socket group ownership permission ..."
	virsh net-info default &>/dev/null && grep -q -w default <(virsh net-list --name) || {
		echo -e "{*INFO*} confiure $virtdconf ..."
		sudo sed -ri -e '/#unix_sock_group = "libvirt"/s/^#//' -e '/#unix_sock_rw_perms = "0770"/s/^#//' $virtdconf 
		sudo egrep -e ^unix_sock_group -e ^unix_sock_rw_perms $virtdconf
		sudo systemctl restart libvirtd && sudo systemctl restart virtlogd

		#export LIBVIRT_DEFAULT_URI=qemu:///system
		echo 'uri_default = "qemu:///system"' >>$pvirtconf
	}

: <<'COMM'
	qemuconf=/etc/libvirt/qemu.conf
	eval echo -e "{INFO} checking if qemu can read image in ~$sudouser ..."
	sudo egrep -q '^#(user|group) =' "$qemuconf" && {
		sudo sed -i '/^#(user|group) =/s/^#//' "$qemuconf"
	}
COMM

	eval setfacl -mu:qemu:rx $sudouserhome

	#first time
	[[ $(id -u) != 0 ]] && {
		id -Gn | egrep -q -w libvirt || {
			echo -e "{WARN} you just joined group libvirt, but still need re-login to enable the change set ..."
			exit 1
		}
	}

	echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ enable libvirt done! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	printf '\33[H\33[2J'
}

is_intranet() {
	local iurl=http://download.devel.redhat.com
	curl --connect-timeout 5 -m 10 --output /dev/null --silent --head --fail $iurl &>/dev/null
}

trap Cleanup EXIT #SIGINT SIGQUIT SIGTERM
mkdir -p $RuntimeTmp

enable_libvirt
is_intranet && {
	Intranet=yes
	baseDownloadUrl=http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved
}

Usage() {
	cat <<-'EOF'
	Usage:
	    $PROG <-d distroname> [OPTIONs] ...

	Options:
	    -h, --help     #Display this help.
	    -I             #create VM by import existing disk image, auto search url according distro name
	                    `-> just could used in Intranet
	    -i <url/path>  #create VM by import existing disk image, value can be url or local path
	    -L             #create VM by using location, auto search url according distro name
	                    `-> just could used in Intranet
	    -l <url>       #create VM by using location
	    --ks <file>    #kickstart file
	    --msize <size> #memory size, default 2048
	    --dsize <size> #disk size, default 16
	    -n|--vmname <name>
	                   #VM name, will auto generate according distro name if omitting
	    -f|--force     #over write existing VM with same name
	    --macvtap <vepa|bridge>
	                   #macvtap mode
	    -p|-pkginstall <pkgs>
	                   #pkgs in default system repo, install by yum or apt-get
	    -b|-brewinstall <args>
	                   #pkgs in brew system or specified by url, install by internal brewinstall.sh
	                    `-> just could used in Intranet
	    -g|-genimage   #generate VM image, after install shutdown VM and generate new qcow2.xz file
	    --rm           #like --rm option of docker/podman, remove VM after quit from console
	    --nocloud|--nocloud-init
	                   #don't create cloud-init iso for the image that is not cloud image
	    --osv <variant>
	                   #OS_VARIANT, optional. virt-install will attempt to auto detect this value
	                   # you can get [-osv variant] info by using:
	                   $ osinfo-query os  #RHEL-7 and later
	                   $ virt-install --os-variant list  #RHEL-6
	    --nointeract   #exit from virsh console after install finish

	EOF
	[[ "$Intranet" = yes ]] && cat <<-EOF
	Example Intranet:
	    $PROG # will enter a TUI show you all available distros that could auto generate source url
	    $PROG RHEL-6.10 -L
	    $PROG RHEL-7.7
	    $PROG RHEL-8.1.0 -f -p "vim wget git"
	    $PROG RHEL-8.1.0 -L -brewinstall 23822847  # brew scratch build id
	    $PROG RHEL-8.1.0 -L -brewinstall kernel-4.18.0-147.8.el8  # brew build name
	    $PROG RHEL-8.2.0-20191024.n.0 -g -b \$(brew search build "kernel-*.elrdy" | sort -Vr | head -n1)

	EOF
	cat <<-EOF
	Example Internet:
	    $PROG centos-5 -l http://vault.centos.org/5.11/os/x86_64/
	    $PROG centos-6 -l http://mirror.centos.org/centos/6.10/os/x86_64/
	    $PROG centos-7 -l http://mirror.centos.org/centos/7/os/x86_64/
	    $PROG centos-8 -l http://mirror.centos.org/centos/8/BaseOS/x86_64/os/
	    $PROG centos-8 -l http://mirror.centos.org/centos/8/BaseOS/x86_64/os/ -brewinstall ftp://url/path/x.rpm
	    $PROG centos-7 -i https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2.xz -pkginstall "vim git wget"
	    $PROG debian-10 -i https://cdimage.debian.org/cdimage/openstack/10.1.5-20191015/debian-10.1.5-20191015-openstack-amd64.qcow2

	Example from local image:
	    $PROG rhel-8-up -i ~/myimages/RHEL-8.1.0-20191015.0/rhel-8-upstream.qcow2.xz --nocloud-init
	    $PROG debian-10 -i /mnt/vm-images/debian-10.1.5-20191015-openstack-amd64.qcow2

	EOF
}

_at=`getopt -o hd:L::l:fn:gb:p:I::i: \
	--long help \
	--long ks: \
	--long rm \
	--long osv: \
	--long os-variant: \
	--long force \
	--long macvtap: \
	--long vmname: \
	--long genimage \
	--long xzopt: \
	--long brewinstall: \
	--long pkginstall: \
	--long getimage \
	--long nocloud-init --long nocloud \
	--long msize: \
	--long dsize: \
	--long nointeract \
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	-d)        Distro=$2; shift 2;;
	-l)        InstallType=location; Location=$2; shift 2;;
	-L)        InstallType=location; [[ -n "$2" ]] && Location=${2#=}; shift 2;;
	-i)        InstallType=import; Imageurl=${2}; shift 2;;
	-I)        InstallType=import; [[ -n "$2" ]] && Imageurl=${2#=}; shift 2;;
	--ks)      KSPath=$2; shift 2;;
	--rm)      RM=yes; shift 1;;
	--xzopt)         XZ="$2"; shift 2;;
	--macvtap)       MacvtapMode="$2"; shift 2;;
	-f|--force)      OVERWRITE="yes"; shift 1;;
	-n|--vmname)     VMName="$2"; shift 2;;
	-g|--genimage)   GenerateImage=yes; shift 1;;
	--getimage)      GetImage=yes; shift 1;;
	-b|--brewinstall) BPKGS="$2"; shift 2;;
	-p|--pkginstall) PKGS="$2"; shift 2;;
	--osv|--os-variant) VM_OS_VARIANT="$2"; shift 2;;
	--nocloud*) NO_CLOUD_INIT="yes"; shift 1;;
	--dsize)         DSIZE="$2"; shift 2;;
	--msize)         MSIZE="$2"; shift 2;;
	--nointeract)    NOINTERACT="yes"; shift 1;;
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
		which distro-compose &>/dev/null || {
			_url=$baseDownloadUrl/utils/distro-compose
			mkdir -p ~/bin && wget -O ~/bin/distro-compose -N -q $_url --no-check-certificate
			chmod +x ~/bin/distro-compose
		}
		distrotrees=$(distro-compose -d "$distro" --distrotrees|egrep 'released|compose')
	}
	urls=$(echo "$distrotrees" | awk '/https?:.*\/'"(${variant}|BaseOS)\/${arch}"'\//{print $3}' | sort -u)
	[[ "$distro" = RHEL5* ]] && {
		urls=$(echo "$distrotrees" | awk "/https?:.*\/${arch}\//"'{print $3}' | sort -u)
	}

	which fastesturl.sh &>/dev/null || {
		_url=$baseDownloadUrl/utils/fastesturl.sh
		mkdir -p ~/bin && wget -O ~/bin/fastesturl.sh -N -q $_url --no-check-certificate
		chmod +x ~/bin/fastesturl.sh
	}
	fastesturl.sh $urls
}

getimageurls() {
	local parenturl=$1
	local suffix_pattern=$2
	local rc=1

	local imagenames=$(curl -L -s ${parenturl} | sed -nr "/.*>(rhel-[^<>]+\\.${suffix_pattern})<.*/{s//\\1/;p}")
	for imagename in $imagenames; do
		if [[ -n "${imagename}" ]]; then
			echo ${parenturl%/}/${imagename}
			rc=0
		fi
	done
	return $rc
}

distro2repos() {
	local distro=$1
	local url=$2
	local Repos=()

	shopt -s nocasematch
	case $distro in
	RHEL-5*|RHEL5*)
		{ read; read os arch verytag verxosv _; } < <(tac -s ' ' <<<"${url//\// }")
		debug_url=${url/\/os/\/debug}
		osv=${verxosv#RHEL-5-}
		Repos+=(
			Server:${url}/Server
			Cluster:${url}/Cluster
			ClusterStorage:${url}/ClusterStorage
			Client:${url}/Client
			Workstation:${url}/Workstation

			${osv}-debuginfo:${debug_url}
		)
		;;
	RHEL-6*|RHEL6*|centos6*|centos-6*)
		{ read; read os arch osv ver _; } < <(tac -s ' ' <<<"${url//\// }")
		debug_url=${url/\/os/\/debug}
		Repos+=(
			${osv}:${url}
			${osv}-SAP:${url/$osv/${osv}-SAP}
			${osv}-SAPHAHA:${url/$osv/${osv}-SAPHAHA}

			${osv}-debuginfo:${debug_url}
			${osv}-SAP-debuginfo:${debug_url/$osv/${osv}-SAP}
			${osv}-SAPHAHA-debuginfo:${debug_url/$osv/${osv}-SAPHAHA}
		)
		;;
	RHEL-7*|RHEL7*|centos7*|centos-7*)
		{ read; read os arch osv ver _; } < <(tac -s ' ' <<<"${url//\// }")
		debug_url=${url/\/os/\/debug\/tree}
		Repos+=(
			${osv}:${url}
			${osv}-optional:${url/$osv/${osv}-optional}
			${osv}-NFV:${url/$osv/${osv}-NFV}
			${osv}-RT:${url/$osv/${osv}-RT}
			${osv}-SAP:${url/$osv/${osv}-SAP}
			${osv}-SAPHAHA:${url/$osv/${osv}-SAPHAHA}

			${osv}-debuginfo:${debug_url}
			${osv}-optional-debuginfo:${debug_url/$osv/${osv}-optional}
			${osv}-NFV-debuginfo:${debug_url/$osv/${osv}-NFV}
			${osv}-RT-debuginfo:${debug_url/$osv/${osv}-RT}
			${osv}-SAP-debuginfo:${debug_url/$osv/${osv}-SAP}
			${osv}-SAPHAHA-debuginfo:${debug_url/$osv/${osv}-SAPHAHA}
		)
		;;
	RHEL-8*|RHEL8*)
		{ read; read os arch osv ver _; } < <(tac -s ' ' <<<"${url//\// }")
		debug_url=${url/\/os/\/debug\/tree}
		Repos+=(
			BaseOS:${url}
			AppStream:${url/BaseOS/AppStream}
			CRB:${url/BaseOS/CRB}
			HighAvailability:${url/BaseOS/HighAvailability}
			NFV:${url/BaseOS/NFV}
			ResilientStorage:${url/BaseOS/ResilientStorage}
			RT:${url/BaseOS/RT}
			SAP:${url/BaseOS/SAP}
			SAPHANA:${url/BaseOS/SAPHANA}

			BaseOS-debuginfo:${debug_url}
			AppStream-debuginfo:${debug_url/BaseOS/AppStream}
			CRB-debuginfo:${debug_url/BaseOS/CRB}
			HighAvailability-debuginfo:${debug_url/BaseOS/HighAvailability}
			NFV-debuginfo:${debug_url/BaseOS/NFV}
			ResilientStorage-debuginfo:${debug_url/BaseOS/ResilientStorage}
			RT-debuginfo:${debug_url/BaseOS/RT}
			SAP-debuginfo:${debug_url/BaseOS/SAP}
			SAPHANA-debuginfo:${debug_url/BaseOS/SAPHANA}
		)
		;;
	esac
	shopt -u nocasematch

	for repo in "${Repos[@]}"; do
		read _name _url <<<"${repo/:/ }"
		curl -connect-timeout 10 -m 20 --output /dev/null --silent --head --fail $_url &>/dev/null &&
			echo "$repo"
	done
}

[[ -z "$Distro" ]] && Distro=$1
[[ -n "$Location" || -n "$Imageurl" ]] && Intranet=no
[[ -z "$Distro" ]] && {
	if [[ "$Intranet" = yes ]]; then
		distrofile=$RuntimeTmp/distro
		which distro-compose &>/dev/null || {
			_url=$baseDownloadUrl/utils/distro-compose
			mkdir -p ~/bin && wget -O ~/bin/distro-compose -N -q $_url --no-check-certificate
			chmod +x ~/bin/distro-compose
		}
		which dialog &>/dev/null || yum install -y dialog &>/dev/null

		mainvers=$(echo -e "RHEL-8\nRHEL-7\nRHEL-6\nRHEL-?5"|sed -e 's/.*/"&" "" 1/')
		dialog --backtitle "$0" --radiolist "please selet family:" 12 40 8 $mainvers 2>$distrofile || { Usage; exit 0; }
		pattern=$(head -n1 $distrofile|sed 's/"//g')
		distroList=$(distro-compose --distrolist|sed -e '/ /d' -e 's/.*/"&" "" 1/'|egrep "$pattern")
		dialog --title "If include nightly build" \
			--backtitle "Do you want nightly build distros?" \
			--yesno "Do you want nightly build distros?" 7 60
		[[ $? = 1 ]] && distroList=$(echo "$distroList"|grep -v '\.n\.[0-9]"')
		dialog --backtitle "$0" --radiolist "please select distro:" 30 60 28 $distroList 2>$distrofile || { Usage; exit 0; }
		Distro=$(head -n1 $distrofile|sed 's/"//g')
		printf '\33[H\33[2J'
	else
		Usage
		exit 1
	fi
}
[[ -z "$Distro" ]] && {
	echo -e "{WARN} you have to select a distro name or specified it by adding command line parameter:\n"
	Usage
	exit 1
}

vmname=${Distro//./}
vmname=${vmname,,}
[[ -n "$VMName" ]] && vmname=${VMName}

if [[ "$InstallType" = import || -n "$GetImage" ]]; then
	if [[ -z "$Imageurl" ]]; then
		echo "{INFO} searching private image url of $Distro ..." >&2
		baseurl=http://download.eng.bos.redhat.com/qa/rhts/lookaside/distro-vm-images/$Distro/
		baseurl=http://download.devel.redhat.com/qa/rhts/lookaside/distro-vm-images/$Distro/
		imageLocation=${baseurl/\/os\//\/images\/}
		read Imageurl _ < <(getimageurls ${imageLocation} "(qcow2|qcow2.xz)")

		if [[ -z "$Imageurl" ]]; then
			echo "{INFO} getting fastest location of $Distro ..." >&2
			Location=$(distro2location $Distro)
			[[ -z "$Location" ]] && {
				echo "{WARN} can not find location info of '$Distro'" >&2
				exit 1
			}
			echo -e " -> $Location"
			echo "{INFO} getting image url according location url ^^^ ..." >&2
			imageLocation=${Location/\/os\//\/images\/}
			read Imageurl _ < <(getimageurls $imageLocation "(qcow2|qcow2.xz)")
			if [[ $? = 0 ]]; then
				echo -e " -> $Imageurl"
				[[ -n "$GetImage" ]] && { exit; }
			else
				[[ -n "$GetImage" ]] && { exit 1; }
				echo "{INFO} can not find image info of '$Distro', switching to Location mode" >&2
				InstallType=location
			fi
		else
			echo -e " -> $Imageurl"
			[[ -n "$GetImage" ]] && { exit; }
			NO_CLOUD_INIT=yes
		fi
	fi
elif [[ "$InstallType" = location ]]; then
	if [[ -z "$Location" ]]; then
		echo "{INFO} getting fastest location of $Distro ..." >&2
		Location=$(distro2location $Distro)
		[[ -z "$Location" ]] && {
			echo "{WARN} can not find distro location. please check if '$Distro' is valid distro" >&2
			exit 1
		}
		echo -e " -> $Location"
	fi
fi

if [[ "$InstallType" = location ]]; then
	[[ -z "$KSPath" ]] && {
		echo "{INFO} generating kickstart file for $Distro ..."
		ksauto=$RuntimeTmp/ks-$VM_OS_VARIANT-$$.cfg
		KSPath=$ksauto
		REPO_OPTS=$(distro2repos $Distro $Location | sed 's/^/--repo /')
		which ks-generator.sh &>/dev/null || {
			_url=$baseDownloadUrl/utils/ks-generator.sh
			mkdir -p ~/bin && wget -O ~/bin/ks-generator.sh -N -q $_url --no-check-certificate
			chmod +x ~/bin/ks-generator.sh
		}
		ks-generator.sh -d $Distro -url $Location $REPO_OPTS >$KSPath

		cat <<-END >>$KSPath
		%post --log=/root/extra-ks-post.log
		yum install -y $PKGS
		wget -O /usr/bin/brewinstall.sh -N -q $baseDownloadUrl/utils/brewinstall.sh --no-check-certificate
		chmod +x /usr/bin/brewinstall.sh
		brewinstall.sh $BPKGS
		%end
		END

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
elif [[ "$InstallType" = import ]]; then
	:
fi

virsh desc $vmname &>/dev/null && {
	if [[ "${OVERWRITE}" = "yes" ]]; then
		echo "{INFO} VM $vmname has been there, remove it ..."
		virsh destroy $vmname 2>/dev/null
		virsh undefine $vmname --remove-all-storage
	else
		echo "{INFO} VM $vmname has been there, if you want overwrite please use --force option"
		exit
	fi
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

virsh net-info default >/dev/null || {
	virsh net-define /usr/share/libvirt/networks/default.xml
	virsh net-autostart default
	virsh net-start default
}

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

echo -e "{INFO} get available vnc port ..."
VNCPORT=${VNCPORT:-7777}
while nc 127.0.0.1 ${VNCPORT} </dev/null &>/dev/null; do
	let VNCPORT++
done

if [[ "$InstallType" = location ]]; then
	echo -e "{INFO} creating VM by using location:\n ->  $Location"
	[[ "$GenerateImage" = yes ]] && {
		sed -i '/^reboot$/s//poweroff/' ${KSPath}
		NOREBOOT=--noreboot
	}
	ksfile=${KSPath##*/}
	virt-install --connect=qemu:///system --hvm --accelerate \
	  --name $vmname \
	  --location $Location \
	  $OS_VARIANT_OPT \
	  --vcpus 2 \
	  --memory ${MSIZE:-2048} \
	  --disk size=${DSIZE:-16} \
	  --network network=default,model=virtio \
	  --network type=direct,source=$(get_default_if),source_mode=$MacvtapMode,model=virtio \
	  --initrd-inject $KSPath \
	  --extra-args="ks=file:/$ksfile console=tty0 console=ttyS0,115200n8" \
	  --vnc --vnclisten 0.0.0.0 --vncport ${VNCPORT} $NOREBOOT &
	installpid=$!
	sleep 5s
	while ! virsh desc $vmname &>/dev/null; do test -d /proc/$installpid || exit 1; sleep 1s; done

	trap - SIGINT
	for ((i=0; i<8; i++)); do
		#clear -x
		printf '\33[H\33[2J'
		NOINTERACT=$NOINTERACT expect -c '
			set timeout -1
			spawn virsh console '"$vmname"'
			trap {
				send_user "You pressed Ctrl+C\n"
			} SIGINT
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
				"Unsupported Hardware Detected" {
					send "\r"
					continue
				}
				"Which would you like to install through" {
					# see: [RHEL 6.1] Anaconda requires user interaction in case of kickstart network activation failing
					send "\r"
					interact
				}

				"reboot: Restarting system" { exit 1 }
				"Restarting system" { exit 1 }

				"reboot: Power down" { exit 0 }
				"Power down" { exit 0 }

				"reboot: System halted" { send_user "\r\rsomething is wrong! cancel installation ..\r\r"; exit 0 }
				"System halted" { send_user "\r\rsomething is wrong! cancel installation ..\r\r"; exit 0 }

				"An unknown error has occurred" {
					interact
				}

				"* login:" { send "root\r" }
			}
			expect "Password:" {
				send "redhat\r"
				send "\r\r\r\r\r\r"
				send "# your are in console, Ctr + ] to exit \r"
				send "\r\r\r\r\r\r"
			}

			if {$env(NOINTERACT) == "yes"} { exit 0 }
			interact
		' && break
		test -d /proc/$installpid || break
		sleep 2
	done
	echo -e "\n{INFO} Quit from console of $vmname"

	# waiting install finish ...
	test -d /proc/$installpid && {
		echo -e "\n{INFO} check/waiting install process finish ..."
		while test -d /proc/$installpid; do sleep 1; [[ $((loop++)) -gt 30 ]] && break; done
	}
	test -d /proc/$installpid && {
		echo -e "\n{INFO} something is wrong(please check disk space), will clean all tmp files ..."
		kill -9 $installpid
		RM=yes
		GenerateImage=
	}

elif [[ "$InstallType" = import ]]; then
	[[ -f $Imageurl ]] && Imageurl=file://$(readlink -f ${Imageurl})
	imagefilename=${Imageurl##*/}
	vmpath=$VMPath/$Distro
	imagefile=$vmpath/$imagefilename
	mkdir -p $vmpath

	echo "{INFO} downloading cloud image file of $Distro to $imagefile ..."
	[[ $Imageurl = file://$imagefile ]] ||
		curl -L $Imageurl -o $imagefile
	[[ -f ${imagefile} ]] || exit 1

	[[ $imagefile = *.xz ]] && {
		echo "{INFO} decompress $imagefile ..."
		xz -d $imagefile
		imagefile=${imagefile%.xz}
		[[ -f ${imagefile} ]] || exit 1
	}

	[[ "$NO_CLOUD_INIT" != yes ]] && {
		echo -e "{INFO} creating cloud-init iso"
		which cloud-init-iso-gen.sh &>/dev/null || {
			_url=$baseDownloadUrl/utils/cloud-init-iso-gen.sh
			mkdir -p ~/bin && wget -O ~/bin/cloud-init-iso-gen.sh -N -q $_url --no-check-certificate
			chmod +x ~/bin/cloud-init-iso-gen.sh
		}
		cloudinitiso=$vmpath/$vmname-cloud-init.iso
		[[ -n "$Location" ]] && {
			REPO_OPTS=$(distro2repos $Distro $Location | sed 's/^/--repo /')
		}
		cloud-init-iso-gen.sh $cloudinitiso -hostname ${vmname} -b "$BPKGS" -p "$PKGS" \
			$REPO_OPTS
		CLOUD_INIT_OPT="--disk $cloudinitiso,device=cdrom"
	}

	echo -e "{INFO} creating VM by import $imagefile"
	virt-install \
	  --name $vmname \
	  --vcpus 2 \
	  --memory ${MSIZE:-1024} \
	  --disk $imagefile \
	  $CLOUD_INIT_OPT \
	  --network network=default,model=virtio \
	  --network type=direct,source=$(get_default_if),source_mode=$MacvtapMode,model=virtio \
	  --import \
	  --vnc --vnclisten 0.0.0.0 --vncport ${VNCPORT} $OS_VARIANT_OPT &
	installpid=$!
	sleep 5s

	trap - SIGINT
	for ((i=0; i<8; i++)); do
		NOINTERACT=$NOINTERACT SHUTDOWN=$GenerateImage expect -c '
			set timeout -1
			spawn virsh console '"$vmname"'
			trap {
				send_user "You pressed Ctrl+C\n"
			} SIGINT
			expect {
				"error: failed to get domain" {
					send "\r"
					puts $expect_out(buffer)
					exit 6
				}
				"error: internal error: character device console0 is not using a PTY" {
					send "\r"
					puts $expect_out(buffer)
					exit 7
				}
				"* login:" { send "root\r" }
			}
			expect "Password:" {
				send "redhat\r"
				send "\r\r\r\r\r\r"
				if {$env(SHUTDOWN) == "yes"} {
					send {while ps axf|grep -A2 "/var/lib/cloud/instance/scripts/runcm[d]"; do echo "{INFO}: cloud-init scirpt is still running .."; sleep 5; done; poweroff}
					send "\r\n"
					"Restarting system" { exit 0 }
				}

				send {while ps axf|grep -A2 "/var/lib/cloud/instance/scripts/runcm[d]"; do echo "{INFO}: cloud-init scirpt is still running .."; sleep 5; done; echo "~~~~~~~~ no cloud-init or cloud-init done ~~~~~~~~"\d}
				send "\r\n"
				expect "or cloud-init done ~~~~~~~~d" {send "\r\r# Now you can take over the keyboard\r\r"}
				send "# and your are in console, Ctr + ] to exit \r"
				send "\r\r"
			}

			if {$env(NOINTERACT) == "yes"} { exit 0 }
			interact
		' && break
		test -d /proc/$installpid || break
		sleep 2
	done
	echo -e "\n{INFO} Quit from console of $vmname"
fi

if [[ "$GenerateImage" = yes ]]; then
	mkdir -p $ImagePath/$Distro
	image=$(virsh dumpxml --domain $vmname | sed -n "/source file=/{s|^.*='||; s|'/>$||; p}")
	newimage=$ImagePath/$Distro/${image##*/}

	echo -e "\n{INFO} force shutdown $vmname ..."
	virsh destroy $vmname 2>/dev/null

	echo -e "\n{INFO} virt-sparsify image $image to ${newimage} ..."
	LIBGUESTFS_BACKEND=direct virt-sparsify ${image} ${newimage}
	ls -lh ${image}
	ls -lh ${newimage}

	echo -e "\n{INFO} xz compress image ..."
	time xz -z -f -T 0 ${XZ:--9} ${newimage}
	ls -lh ${newimage}.xz

	echo -e "\n{INFO} undefine temprory temporary VM $vmname ..."
	virsh undefine $vmname --remove-all-storage
else
	#echo "{DEBUG} VNC port ${VNCPORT}"
	echo -e "\n{INFO} you can try login $vmname again by using:"
	echo -e "  $ vncviewer $HOSTNAME:$VNCPORT  #from remote"
	echo -e "  $ virsh console $vmname"
	echo -e "  $ ssh foo@$vmname  #password: redhat"
	read addr host < <(getent hosts $vmname)
	[[ -n "$addr" ]] && {
		echo -e "  $ ssh foo@$addr  #password: redhat"
	}
fi

[[ "$RM" = yes && "$GenerateImage" != yes ]] && {
	echo -e "\n{INFO} dist removing VM $vmname .."
	virsh destroy $vmname 2>/dev/null
	virsh undefine $vmname --remove-all-storage
	[[ -n "$vmpath" ]] && rmdir $vmpath 2>/dev/null
	exit
}
