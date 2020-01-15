#!/bin/bash

rpm -q restraint-rhts restraint-client restraint && {
	echo "{INFO} restraint has been installed in your system"
	exit
}

#__main__
if grep -q NAME=Fedora /etc/os-release; then
	cat <<-'EOF' >/etc/yum.repos.d/beaker-harness.repo
	[beaker-harness]
	name=Beaker harness - Fedora$releasever
	baseurl=https://download.devel.redhat.com/beakerrepos/harness/Fedora$releasever/
	enabled=1
	gpgcheck=0
	EOF
else
	cat <<-'EOF' >/etc/yum.repos.d/beaker-harness.repo
	[beaker-harness]
	name=Beaker harness - RedHatEnterpriseLinux$releasever
	baseurl=https://download.devel.redhat.com/beakerrepos/harness/RedHatEnterpriseLinux$releasever/
	enabled=1
	gpgcheck=0
	EOF
fi

# fix ssl certificate verify failed
curl -s https://password.corp.redhat.com/RH-IT-Root-CA.crt -o /etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt
curl -s https://password.corp.redhat.com/legacy.crt -o /etc/pki/ca-trust/source/anchors/legacy.crt
update-ca-trust

yum install -y restraint-rhts restraint-client restraint
systemctl enable restraintd.service
systemctl start restraintd.service
