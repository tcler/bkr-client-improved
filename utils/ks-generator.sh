#!/bin/bash
#
# get simple template from here:
#  https://access.redhat.com/labs/kickstartconfig
# and replace some info in the template

Distro=
URL=
Repos=()
Post=
NetCommand=
KeyCommand=

Usage() {
	cat <<-EOF >&2
	Usage:
	 $0 <-d distroname> <-url url> [-repo name1:url1 [-repo name2:url2 ...]] [-post <script file>]

	Example:
	 $0 -d centos-5 -url http://vault.centos.org/5.11/os/x86_64/
	 $0 -d centos-6 -url http://mirror.centos.org/centos/6.10/os/x86_64/
	 $0 -d centos-7 -url http://mirror.centos.org/centos/7/os/x86_64/
	 $0 -d centos-8 -url http://mirror.centos.org/centos/8/BaseOS/x86_64/os/
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
RHEL-5*|RHEL5*|centos5*|centos-5*)
	Packages="@base @cifs-file-server @nfs-file-server redhat-lsb-core vim-enhanced git iproute screen"
	{ read; read os arch osv ver _; } < <(tac -s ' ' <<<"${URL//\// }")
	debug_url=${URL/\/os/\/debug}
	[[ $osv = [0-7]* ]] && osv=centos-${osv%%[.-]*}
	Repos+=(
		${osv}:${URL}
		${osv}-debuginfo:${debug_url}
	)
NetCommand="network --device=eth0 --bootproto=dhcp"
KeyCommand="key --skip"
	;;
RHEL-6*|RHEL6*|centos6*|centos-6*)
	Packages="@base @cifs-file-server @nfs-file-server redhat-lsb-core vim-enhanced git iproute screen"
	{ read; read os arch osv ver _; } < <(tac -s ' ' <<<"${URL//\// }")
	debug_url=${URL/\/os/\/debug}
	[[ $osv = [0-7]* ]] && osv=centos-${osv%%[.-]*}
	Repos+=(
		${osv}:${URL}
		${osv}-SAP:${URL/$osv/${osv}-SAP}
		${osv}-SAPHAHA:${URL/$osv/${osv}-SAPHAHA}

		${osv}-debuginfo:${debug_url}
		${osv}-SAP-debuginfo:${debug_url/$osv/${osv}-SAP}
		${osv}-SAPHAHA-debuginfo:${debug_url/$osv/${osv}-SAPHAHA}
	)
NetCommand="network --device=eth0 --bootproto=dhcp"
KeyCommand="key --skip"
	;;
RHEL-7*|RHEL7*|centos7*|centos-7*)
	Packages="-iwl* @base @file-server redhat-lsb-core vim-enhanced git iproute screen"
	{ read; read os arch osv ver _; } < <(tac -s ' ' <<<"${URL//\// }")
	debug_url=${URL/\/os/\/debug\/tree}
	[[ $osv = [0-7]* ]] && osv=centos-${osv%%[.-]*}
	Repos+=(
		${osv}:${URL}
		${osv}-optional:${URL/$osv/${osv}-optional}
		${osv}-NFV:${URL/$osv/${osv}-NFV}
		${osv}-RT:${URL/$osv/${osv}-RT}
		${osv}-SAP:${URL/$osv/${osv}-SAP}
		${osv}-SAPHAHA:${URL/$osv/${osv}-SAPHAHA}

		${osv}-debuginfo:${debug_url}
		${osv}-optional-debuginfo:${debug_url/$osv/${osv}-optional}
		${osv}-NFV-debuginfo:${debug_url/$osv/${osv}-NFV}
		${osv}-RT-debuginfo:${debug_url/$osv/${osv}-RT}
		${osv}-SAP-debuginfo:${debug_url/$osv/${osv}-SAP}
		${osv}-SAPHAHA-debuginfo:${debug_url/$osv/${osv}-SAPHAHA}
	)
	;;
RHEL-8*|RHEL8*|centos8*|centos-8*)
	Packages="-iwl* @standard @file-server redhat-lsb-core vim-enhanced git iproute screen"
	{ read; read os arch osv ver _; } < <(tac -s ' ' <<<"${URL//\// }")
	debug_url=${URL/\/os/\/debug\/tree}
	Repos+=(
		BaseOS:${URL}
		AppStream:${URL/BaseOS/AppStream}
		CRB:${URL/BaseOS/CRB}
		HighAvailability:${URL/BaseOS/HighAvailability}
		NFV:${URL/BaseOS/NFV}
		ResilientStorage:${URL/BaseOS/ResilientStorage}
		RT:${URL/BaseOS/RT}
		SAP:${URL/BaseOS/SAP}
		SAPHANA:${URL/BaseOS/SAPHANA}

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


# output final ks cfg
Packages=${Packages// /$'\n'}

cat <<KSF
lang en_US
keyboard us
timezone Asia/Shanghai --isUtc
rootpw \$1\$zAwkhhNB\$rxjwuf7RLTuS6owGoL22I1 --iscrypted

user --name=foo --groups=wheel --iscrypted --password=\$1\$zAwkhhNB\$rxjwuf7RLTuS6owGoL22I1
user --name=bar --iscrypted --password=\$1\$zAwkhhNB\$rxjwuf7RLTuS6owGoL22I1

#platform x86, AMD64, or Intel EM64T
reboot
$NetCommand
text
url --url=$URL
$KeyCommand
bootloader --location=mbr --append="rhgb quiet crashkernel=auto"
zerombr
clearpart --all --initlabel
autopart
auth --passalgo=sha512 --useshadow
selinux --enforcing
firewall --enabled --http --ftp --smtp --ssh
skipx
firstboot --disable

%packages --ignoremissing
${Packages}
%end

KSF

for repo in "${Repos[@]}"; do
	read name url <<<"${repo/:/ }"
	curl --output /dev/null --silent --head --fail $url || continue
	echo "repo --name=$name --baseurl=$url"
done

echo -e "\n%post"

# There's been repo files in CentOS by default, so clear Repos array
[[ $URL = *centos* ]] && Repos=()

for repo in "${Repos[@]}"; do
	read name url <<<"${repo/:/ }"
	curl --output /dev/null --silent --head --fail $url || continue
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

%post --log=/root/my-ks-post.log
# post-installation script:
test -f /etc/dnf/dnf.conf && echo strict=0 >>/etc/dnf/dnf.conf

echo "%wheel        ALL=(ALL)       ALL" >> /etc/sudoers

ver=$(LANG=C rpm -q --qf %{version} centos-release)
[[ "$ver" = 5* ]] && sed -i -e 's;mirror.centos.org/centos;vault.centos.org;' -e 's/^mirror/#&/' -e 's/^#base/base/' /etc/yum.repos.d/*
[[ "$ver" = 5 ]] && sed -i -e 's;\$releasever;5.11;' /etc/yum.repos.d/*

%end

KSF

[[ -n "$Post" && -f "$Post" ]] && {
	cat $Post
}
