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
	local name=$(lsb_release -sir|awk '{print $1}')
	local verx=$(lsb_release -sr|awk -F. '{print $1}')

	pushd /etc/yum.repos.d
	case $name in
	RedHatEnterprise*|CentOS*)
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
		8)
			curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-8-baseos.repo
			yum install -y koji brewkoji python3-koji python3-pycurl || rm rcm-tools-*.repo
			;;
		9)
			yum install -y python-requests
			rpm -ivh --force --nodeps \
				https://kojipkgs.fedoraproject.org//packages/koji/1.23.0/2.fc33/noarch/koji-1.23.0-2.fc33.noarch.rpm \
				https://kojipkgs.fedoraproject.org//packages/koji/1.23.0/2.fc33/noarch/python3-koji-1.23.0-2.fc33.noarch.rpm \
				https://download.devel.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-RHEL-8/compose/BaseOS/x86_64/os/Packages/brewkoji-1.24-1.el8.noarch.rpm
		esac
		;;
	Fedora*)
		curl -L -O http://download.devel.redhat.com/rel-eng/internal/rcm-tools-fedora.repo
		yum install -y koji brewkoji || rm rcm-tools-*.repo
		;;
	esac
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
