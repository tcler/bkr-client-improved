#!/bin/bash
#author jiyin@redhat.com

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

	yum install -y redhat-lsb-core &>/dev/null
	local verx=$(rpm -E %rhel)

	pushd /etc/yum.repos.d
	if [[ $(rpm -E %rhel) != %rhel ]]; then
		case $verx in
		[56])
			for type in server client workstation; do
				curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rhel-${verx}/rcm-tools-rhel-${verx}-${type}.repo
				yum install -y koji brewkoji && break || rm rcm-tools-*.repo
			done
			;;
		7)
			for type in server client workstation; do
				curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-${verx}-${type}.repo
				yum install -y koji brewkoji && break || rm rcm-tools-*.repo
			done
			;;
		8|9)
			curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-${verx}-baseos.repo
			yum install -y koji brewkoji python3-koji python3-pycurl || rm rcm-tools-*.repo
			;;
		esac
	elif [[ $(rpm -E %fedora) != %fedora ]]; then
		curl -L -O http://download.devel.redhat.com/rel-eng/internal/rcm-tools-fedora.repo
		yum install -y koji brewkoji || rm rcm-tools-*.repo
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
	yum --setopt=strict=0 install -y koji python-koji python-pycurl brewkoji
which brew &>/dev/null || installBrew2
yum install -y bash-completion-brew

which brew
