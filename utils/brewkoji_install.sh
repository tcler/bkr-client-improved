#!/bin/bash
#author jiyin@redhat.com

installBrew2() {
	#https://mojo.redhat.com/docs/DOC-1024827
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

	local name=$(lsb_release -sir|awk '{print $1}')
	local verx=$(lsb_release -sr|awk -F. '{print $1}')

	pushd /etc/yum.repos.d
	case $name in
	RedHatEnterprise*)
		case $verx in
		6|7)
			for type in server client workstation; do
				curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-${verx}-${type}.repo
				yum install -y koji brewkoji && break || rm rcm-tools-*.repo
			done
			;;
		8)
			curl -L -O http://download.devel.redhat.com/rel-eng/RCMTOOLS/rcm-tools-rhel-8-baseos.repo
			yum install -y koji brewkoji python3-koji python3-pycurl || rm rcm-tools-*.repo
			;;
		esac
		;;
	Fedora*)
		curl -L -O http://download.devel.redhat.com/rel-eng/internal/rcm-tools-fedora.repo
		yum install -y koji brewkoji
		;;
	esac
	popd

	which brew &>/dev/null
}
installBrewFromSourceCode() {
	git -c http.sslVerify=false clone  https://code.engineering.redhat.com/gerrit/rcm-brewkoji.git
	cd rcm-brewkoji
	make install >/dev/null
	cd .. && rm -rf rcm-brewkoji

	which brew &>/dev/null
}

# fix ssl certificate verify failed
curl -s https://password.corp.redhat.com/RH-IT-Root-CA.crt -o /etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt
curl -s https://password.corp.redhat.com/legacy.crt -o /etc/pki/ca-trust/source/anchors/legacy.crt
update-ca-trust

# install koji & brew
which brew &>/dev/null ||
	yum --setopt=strict=0 install -y koji python-koji python-pycurl brewkoji
which brew &>/dev/null || installBrew2 || installBrewFromSourceCode

which brew
