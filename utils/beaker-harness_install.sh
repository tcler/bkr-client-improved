#!/bin/bash
#ref: https://restraint.readthedocs.io/en/latest/install.html
#ref: https://restraint.readthedocs.io/en/latest/commands.html

rpm -q restraint-rhts restraint-client restraint && {
	echo "{INFO} restraint has been installed in your system"
	exit
}

#__main__
verx=$(rpm -E %rhel)
if grep -q NAME=Fedora /etc/os-release; then
	cat <<-'EOF' >/etc/yum.repos.d/beaker-harness.repo
	[beaker-harness]
	name=Beaker harness - Fedora$releasever
	baseurl=https://download.devel.redhat.com/beakerrepos/harness/Fedora$releasever/
	enabled=1
	gpgcheck=0
	skip_if_unavailable=1
	EOF
else
	cat <<-EOF >/etc/yum.repos.d/beaker-harness.repo
	[beaker-harness]
	name=Beaker harness - RedHatEnterpriseLinux$verx
	baseurl=https://download.devel.redhat.com/beakerrepos/harness/RedHatEnterpriseLinux$verx/
	enabled=1
	gpgcheck=0
	skip_if_unavailable=1
	EOF
fi

# fix ssl certificate verify failed
curl -s https://password.corp.redhat.com/RH-IT-Root-CA.crt -o /etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt
curl -s https://password.corp.redhat.com/legacy.crt -o /etc/pki/ca-trust/source/anchors/legacy.crt
update-ca-trust

yum install -y restraint-rhts restraint-client restraint
systemctl enable restraintd.service
systemctl start restraintd.service
