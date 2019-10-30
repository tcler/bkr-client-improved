#!/bin/bash
# author: yin-jianhong@163.com
# ref: https://cloudinit.readthedocs.io/en/latest/topics/examples.html

HostName=mylinux
Repos=()
BPKGS=
PKGS=

_at=`getopt -o hp:b: \
	--long help \
	--long hostname: \
	--long repo: \
	--long pkginstall: \
	--long brewinstall: \
    -a -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help) Usage; shift 1; exit 0;;
	--hostname) HostName="$2"; shift 2;;
	--repo) Repos+=($2); shift 2;;
	-p|--pkginstall) PKGS="$2"; shift 2;;
	-b|--brewinstall) BPKGS="$2"; shift 2;;
	--) shift; break;;
	esac
done

Usage() {
	cat <<-EOF >&2
	Usage: $0 <iso file path> [--hostname name] [--repo name:url [--repo name:url]] [-b|--brewinstall "pkg list"] [-p|--pkginstall "pkg list"]
	EOF
}

isof=$1
if [[ -z "$isof" ]]; then
	Usage
	exit
else
	mkdir -p $(dirname $isof)
	touch $isof
	isof=$(readlink -f $isof)
fi

tmpdir=.cloud-init-iso-gen-$$
mkdir -p $tmpdir
pushd $tmpdir &>/dev/null

echo "local-hostname: ${HostName}.local" >meta-data

cat >user-data <<-EOF
#cloud-config
users:
  - default

  - name: root
    plain_text_passwd: redhat
    lock_passwd: false

  - name: foo
    group: sudo
    plain_text_passwd: redhat
    lock_passwd: false

chpasswd: { expire: False }

yum_repos:
$(
for repo in "${Repos[@]}"; do
read name url <<<"${repo/:/ }"
[[ ${url:0:1} = / ]] && { name=; url=$repo; }
name=${name:-repo$((i++))}
cat <<REPO
  ${name}:
    name: $name
    baseurl: "$url"
    enabled: true
    gpgcheck: false
    skip_if_unavailable: true

REPO
done
)

runcmd:
  - test -f /etc/dnf/dnf.conf && { echo strict=0 >>/etc/dnf/dnf.conf; dnf install -y yum; }
  - echo "PasswordAuthentication yes" >>/etc/ssh/sshd_config && service sshd restart
  - which yum && yum install -y vim curl wget $PKGS
  - which apt-get && apt-get install -y vim curl wget $PKGS
  - which yum && curl -L -m 30 -o /usr/bin/brewinstall.sh "http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved/utils/brewinstall.sh" &&
    chmod +x /usr/bin/brewinstall.sh && brewinstall.sh $BPKGS
EOF

genisoimage -output $isof -volid cidata -joliet -rock user-data meta-data

popd &>/dev/null

rm -rf $tmpdir
