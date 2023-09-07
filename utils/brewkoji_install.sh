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
	baseUrl=http://download.devel.redhat.com/rhel-$verx
	curl -L $baseUrl -s | grep -q 404 &&
		baseUrl=http://download.eng.pek2.redhat.com/rhel-$verx
	if [[ $(rpm -E %rhel) != %rhel ]]; then
		case $verx in
		[567])
			type=workstation
			pkglist='koji brewkoji'
			;;
		8|9)
			type=BaseOS
			pkglist='brewkoji python3-pycurl'
			;;
		esac
		repourl=$baseUrl/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-RHEL-$verx/compose/$type/$(uname -m)/os
		cat <<-EOF >/etc/yum.repos.d/rcm-tools-2.repo
		[rcm-tools]
		name=RCM TOOLS 2
		baseurl=$repourl
		enabled=1
		gpgcheck=0
		EOF
		yum install --setopt=sslverify=0 -y $pkglist || rm rcm-tools-*.repo
		[[ $verx -ge 8 ]] && { rpm -ivh --force --nodeps \
		    https://kojipkgs.fedoraproject.org/packages/koji/1.29.0/1.el${verx}/noarch/koji-1.29.0-1.el${verx}.noarch.rpm \
		    https://kojipkgs.fedoraproject.org/packages/koji/1.29.0/1.el${verx}/noarch/python3-koji-1.29.0-1.el${verx}.noarch.rpm
		}
	elif [[ $(rpm -E %fedora) != %fedora ]]; then
		curl -L -O http://download.devel.redhat.com/rel-eng/internal/rcm-tools-fedora.repo
		yum install --setopt=sslverify=0 -y koji brewkoji || rm rcm-tools-*.repo
	fi
	popd

	which brew &>/dev/null
}

# fix ssl certificate verify failed
# https://certs.corp.redhat.com/ https://docs.google.com/spreadsheets/d/1g0FN13NPnC38GsyWG0aAJ0v8FljNDlqTTa35ap7N46w/edit#gid=0
(cd /etc/pki/ca-trust/source/anchors && curl -Ls --remote-name-all https://certs.corp.redhat.com/{2022-IT-Root-CA.pem,2015-IT-Root-CA.pem,ipa.crt} && update-ca-trust)

# install koji & brew
which brew &>/dev/null ||
	OSV=$(rpm -E %rhel)
	if ! grep -E -q '^!?epel' < <(yum repolist 2>/dev/null); then
		[[ "$OSV" != "%rhel" ]] && yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSV}.noarch.rpm 2>/dev/null
	fi
	yum --setopt=strict=0 --setopt=sslverify=0 install -y koji python3-koji python3-pycurl brewkoji
which brew &>/dev/null || installBrew2
yum install --setopt=sslverify=0 -y bash-completion-brew

which brew
rm -rf /etc/yum.repos.d/rcm-tools-*.repo
