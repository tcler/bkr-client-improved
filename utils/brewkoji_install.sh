#!/bin/bash
#author jiyin@redhat.com

P=$0; [[ $0 = /* ]] && P=${0##*/}
switchroot() {
	[[ $(id -u) != 0 ]] && {
		echo -e "{WARN} $P need root permission, switch to:\n  sudo $P $@" | GREP_COLORS='ms=1;30' grep --color=always . >&2
		exec sudo $P "$@"
	}
}
switchroot "$@"

installBrew2() {
	#https://mojo.redhat.com/docs/DOC-1024827
	#https://docs.engineering.redhat.com/display/RCMDOC/RCM+Tools+Release+Guide
	urls="
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-6-server.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-6-client.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-6-workstation.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-7-server.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-7-client.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-7-workstation.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-8-baseos.repo
	curl -L -O http://download.devel.redhat.com/rel-eng/internal/rcm-tools-fedora.repo
	"

	local verx=$(rpm -E %rhel)

	pushd /etc/yum.repos.d
	if [[ $(rpm -E %rhel) != %rhel ]]; then
		case $verx in
		[56])
			for type in server client workstation; do
				curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rhel-${verx}/rcm-tools-rhel-${verx}-${type}.repo
				yum install --setopt=sslverify=0 -y koji brewkoji && break || rm rcm-tools-*.repo
			done
			;;
		7)
			for type in server client workstation; do
				curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-${verx}-${type}.repo
				yum install --setopt=sslverify=0 -y koji brewkoji && break || rm rcm-tools-*.repo
			done
			;;
		8|9)
			curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-${verx}-baseos.repo
			yum install --setopt=sslverify=0 -y brewkoji python3-pycurl || rm rcm-tools-*.repo
			rpm -ivh --force --nodeps \
				https://kojipkgs.fedoraproject.org/packages/koji/1.29.0/1.el${verx}/noarch/koji-1.29.0-1.el${verx}.noarch.rpm \
				https://kojipkgs.fedoraproject.org/packages/koji/1.29.0/1.el${verx}/noarch/python3-koji-1.29.0-1.el${verx}.noarch.rpm
			;;
		esac
	elif [[ $(rpm -E %fedora) != %fedora ]]; then
		curl -L -O http://download.devel.redhat.com/rel-eng/internal/rcm-tools-fedora.repo
		yum install --setopt=sslverify=0 -y koji brewkoji || rm rcm-tools-*.repo
	fi
	popd

	which brew &>/dev/null
}

# fix ssl certificate verify failed
curl -s https://password.corp.redhat.com/RH-IT-Root-CA.crt -o /etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt
curl -s https://password.corp.redhat.com/legacy.crt -o /etc/pki/ca-trust/source/anchors/legacy.crt
update-ca-trust

# install koji & brew
which brew &>/dev/null ||
	OSV=$(rpm -E %rhel)
	if ! egrep -q '^!?epel' < <(yum repolist 2>/dev/null); then
		[[ "$OSV" != "%rhel" ]] && yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
	fi
	yum --setopt=strict=0 --setopt=sslverify=0 install -y koji python3-koji python3-pycurl brewkoji
which brew &>/dev/null || installBrew2
yum install --setopt=sslverify=0 -y bash-completion-brew

which brew
rm -rf /etc/yum.repos.d/rcm-tools-*.repo
