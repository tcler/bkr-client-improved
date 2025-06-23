#!/bin/bash
#ref: https://restraint.readthedocs.io/en/latest/install.html
#ref: https://restraint.readthedocs.io/en/latest/commands.html

rpm -q restraint-client restraint && {
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
	sslverify=0
	EOF
else
	cat <<-EOF >/etc/yum.repos.d/beaker-harness.repo
	[beaker-harness]
	name=Beaker harness - RedHatEnterpriseLinux$verx
	baseurl=https://download.devel.redhat.com/beakerrepos/harness/RedHatEnterpriseLinux$verx/
	enabled=1
	gpgcheck=0
	skip_if_unavailable=1
	sslverify=0
	EOF
fi

# fix ssl certificate verify failed
# https://certs.corp.redhat.com/ https://docs.google.com/spreadsheets/d/1g0FN13NPnC38GsyWG0aAJ0v8FljNDlqTTa35ap7N46w/edit#gid=0
(cd /etc/pki/ca-trust/source/anchors && curl -Ls --remote-name-all https://certs.corp.redhat.com/{2022-IT-Root-CA.pem,2015-IT-Root-CA.pem,ipa.crt,mtls-ca-validators.crt,RH-IT-Root-CA.crt} && update-ca-trust)

yum install -y restraint-client restraint
systemctl enable restraintd.service
systemctl start restraintd.service
