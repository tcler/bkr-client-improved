#!/bin/bash

rpm -q beaker-client && {
	echo "{INFO} beaker-client has been installed in your system"
	exit
}

#__main__
kuser=$1

if grep -q NAME=Fedora /etc/os-release; then
	cat <<-'EOF' >/etc/yum.repos.d/beaker-client.repo
	[beaker-client]
	name=Beaker Client - Fedora$releasever
	baseurl=http://download.lab.bos.redhat.com/beakerrepos/client/Fedora$releasever/
	enabled=1
	gpgcheck=0
	EOF

	cat <<-'EOF' >/etc/yum.repos.d/beaker-harness.repo
	[beaker-harness]
	name=Beaker harness - Fedora$releasever
	baseurl=https://download.devel.redhat.com/beakerrepos/harness/Fedora$releasever/
	enabled=1
	gpgcheck=0
	EOF
else
	cat <<-'EOF' >/etc/yum.repos.d/beaker-client.repo
	[beaker-client]
	name=Beaker Client - RedHatEnterpriseLinux$releasever
	baseurl=http://download.lab.bos.redhat.com/beakerrepos/client/RedHatEnterpriseLinux$releasever/
	enabled=1
	gpgcheck=0
	EOF

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

yum install -y beaker-client

echo "{INFO} create /etc/beaker/client.conf"
[[ -f /etc/beaker/client.conf ]] || {
	cat <<-EOF >/etc/beaker/client.conf
	HUB_URL = "https://beaker.engineering.redhat.com"
	AUTH_METHOD = "krbv"
	KRB_REALM = "REDHAT.COM"
	#USERNAME = "${kuser:-krb5_useranme}"
	EOF
}

echo "{INFO} create /etc/krb5.conf"
cp -v /etc/krb5.conf /etc/krb5.conf.orig
cat <<-EOF >/etc/krb5.conf
includedir /etc/krb5.conf.d/

[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_realm = REDHAT.COM
 default_ccache_name = KEYRING:persistent:%{uid}

[realms]
  REDHAT.COM = {
   kdc = kerberos01.core.prod.int.phx2.redhat.com.:88
   kdc = kerberos01.core.prod.int.ams2.redhat.com.:88
   kdc = kerberos01.core.prod.int.sin2.redhat.com.:88
   admin_server = kerberos.corp.redhat.com.:749
   default_domain = redhat.com
  }

[domain_realm]
# .example.com = EXAMPLE.COM
# example.com = EXAMPLE.COM
 .redhat.com = REDHAT.COM
 redhat.com = REDHAT.COM
EOF

yum install -y krb5-workstation

cat <<EOF
---
  install complete, you still need to config the /etc/beaker/client.conf or
  ~/.beaker_client/config: fix value of USERNAME and do follow command:
    kinit ${kuser:-krb5_useranme}
    bkr whoami
EOF
