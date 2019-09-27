#!/bin/bash
#
# get simple template from here:
#  https://access.redhat.com/labs/kickstartconfig
# and replace some info in the template

Distro=
URL=
Repos=()
Post=

Usage() {
	cat <<-EOF >&2
	Usage:
	 $0 <-d distroname> <-url url> [-repo name1:url1 [-repo name2:url2 ...]] [-post <script file>]
	EOF
}

_at=`getopt -o hd: \
	--long help \
	--long url: \
	--long repo: \
	--long post: \
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	-d)        Distro=$2; shift 2;;
	--url)     URL="$2"; shift 2;;
	--repo)    Repos+=("$2"); shift 2;;
	--post)    Post="$2"; shift 2;;
	--) shift; break;;
	esac
done

[[ -z "$Distro" || -z "$URL" ]] && {
	Usage
	exit 1
}

shopt -s nocasematch
case $Distro in
RHEL-7*|RHEL7*)
	Packages="@base @identity-management-server @file-server nfstest nfsometer
@directory-server openldap-servers krb5-server-ldap krb5-server migrationtools samba
@ftp-server @system-admin-tools symlinks dump screen tree hardlink expect crypto-utils
scrub system-storage-manager lsscsi"
	;;
RHEL-8*|RHEL8*)
	Packages="@standard @file-server isns-utils @directory-server krb5-server samba
@ftp-server @web-server @network-server"
	debug_url=${URL/\/os/\/debug\/tree}
	Repos+=(
BaseOS:${URL/BaseOS/BaseOS}
AppStream:${URL/BaseOS/AppStream}
CRB:${URL/BaseOS/CRB}
HighAvailability:${URL/BaseOS/HighAvailability}
NFV:${URL/BaseOS/NFV}
ResilientStorage:${URL/BaseOS/ResilientStorage}
RT:${URL/BaseOS/RT}
SAP:${URL/BaseOS/SAP}
SAPHANA:${URL/BaseOS/SAPHANA}

BaseOS-debuginfo:${debug_url/BaseOS/BaseOS}
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


# output final ks cfg
Packages=${Packages// /$'\n'}

cat <<KSF
lang en_US
keyboard us
timezone Asia/Shanghai --isUtc
rootpw \$1\$zAwkhhNB\$rxjwuf7RLTuS6owGoL22I1 --iscrypted

#platform x86, AMD64, or Intel EM64T
reboot
text
url --url=$URL
bootloader --location=mbr --append="rhgb quiet crashkernel=auto"
zerombr
clearpart --all --initlabel
autopart
auth --passalgo=sha512 --useshadow
selinux --enforcing
firewall --enabled --http --ftp --smtp --ssh
skipx
firstboot --disable

%packages
${Packages}
%end

KSF

for repo in "${Repos[@]}"; do
	read name url <<<"${repo/:/ }"
	echo "repo --name=$name --baseurl=$url"
done

echo -e "\n%post"
for repo in "${Repos[@]}"; do
	read name url <<<"${repo/:/ }"
	cat <<-EOF
	cat <<REPO >/etc/yum.repos.d/$name.repo
	[$name]
	name=$name
	baseurl=$url
	enabled=1
	gpgcheck=0
	skip_if_unavailable=1
	REPO

	EOF
done
echo -e "%end\n"

cat <<'KSF'

%post
# post-installation script:
test -f /etc/dnf/dnf.conf && echo strict=0 >>/etc/dnf/dnf.conf

yum install -y gcc wget screen bc redhat-lsb-core sg3_utils sg3_utils-libs sg3_utils-devel rsyslog python2
yum install -y libnsl2 libtirpc-devel python2-lxml python3-lxml
%end

KSF

[[ -n "$Post" && -f "$Post" ]] && {
	cat $Post
}
