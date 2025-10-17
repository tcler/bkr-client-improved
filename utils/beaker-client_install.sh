#!/bin/bash

#__main__
kuser=$1
verx=$(rpm -E %rhel)

if grep -E -q ^NAME=.?Fedora /etc/os-release; then
	cat <<-'EOF' >/etc/yum.repos.d/beaker-client.repo
	[beaker-client]
	name=Beaker Client - Fedora$releasever
	baseurl=http://download.devel.redhat.com/beakerrepos/client/Fedora$releasever
	enabled=1
	gpgcheck=0
	skip_if_unavailable=1
	sslverify=0
	EOF

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
	cat <<-'EOF' >/etc/yum.repos.d/beaker-client.repo
	[beaker-client]
	name=Beaker Client - RedHatEnterpriseLinux$releasever
	baseurl=http://download.devel.redhat.com/beakerrepos/client/RedHatEnterpriseLinux$releasever/
	enabled=1
	gpgcheck=0
	skip_if_unavailable=1
	sslverify=0
	EOF

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

rpm -q beaker-client && {
	echo "{INFO} beaker-client has been installed in your system"
	exit
}

if [[ -f conf/rh-nm-openvpn-config.tgz ]]; then
	(cd /; tar zxf $OLDPWD/conf/rh-nm-openvpn-config.tgz)
fi

# fix ssl certificate verify failed
# https://certs.corp.redhat.com/ https://docs.google.com/spreadsheets/d/1g0FN13NPnC38GsyWG0aAJ0v8FljNDlqTTa35ap7N46w/edit#gid=0
(cd /etc/pki/ca-trust/source/anchors && curl -Ls --remote-name-all https://certs.corp.redhat.com/{2022-IT-Root-CA.pem,2015-IT-Root-CA.pem,ipa.crt,mtls-ca-validators.crt,RH-IT-Root-CA.crt} && update-ca-trust)

yum install -y beaker-client

echo "{INFO} create /etc/beaker/client.conf"
[[ -f /etc/beaker/client.conf ]] || {
	cat <<-EOF >/etc/beaker/client.conf
	HUB_URL = "https://beaker.engineering.redhat.com"
	AUTH_METHOD = "krbv"
	KRB_REALM = "IPA.REDHAT.COM"
	#USERNAME = "${kuser:-krb5_useranme}"
	EOF
}

echo "{INFO} create /etc/krb5.conf"
cp -v /etc/krb5.conf /etc/krb5.conf.orig
cat <<-'EOF' >/etc/krb5.conf
# Configuration snippets may be placed in this directory as well
#includedir /etc/krb5.conf.d/

[libdefaults]
  default_realm = IPA.REDHAT.COM
  dns_lookup_realm = true
  dns_lookup_kdc = true
  rdns = false
  dns_canonicalize_hostname = false
  ticket_lifetime = 24h
  forwardable = true
  udp_preference_limit = 0
  default_ccache_name = KEYRING:persistent:%{uid}

[realms]
  REDHAT.COM = {
    default_domain = redhat.com
    dns_lookup_kdc = true
    master_kdc = kerberos.corp.redhat.com
    admin_server = kerberos.corp.redhat.com
  }

  #make sure to save the IPA CA cert
  #mkdir -p /etc/ipa && curl -o /etc/ipa/ca.crt https://certs.corp.redhat.com/ipa.crt
  IPA.REDHAT.COM = {
    pkinit_anchors = FILE:/etc/ipa/ca.crt
    pkinit_pool = FILE:/etc/ipa/ca.crt
    default_domain = ipa.redhat.com
    dns_lookup_kdc = true
    # Trust tickets issued by legacy realm on this host
    auth_to_local = RULE:[1:$1@$0](.*@REDHAT\.COM)s/@.*//
    auth_to_local = DEFAULT
  }

#DO NOT ADD A [domain_realms] section
#https://mojo.redhat.com/docs/DOC-1166841
#https://source.redhat.com/groups/public/identity-access-management/identity__access_management_wiki/how_to_kerberos_realm_referrals
EOF

mkdir -p /etc/ipa && curl -o /etc/ipa/ca.crt https://certs.corp.redhat.com/ipa.crt

yum install -y krb5-workstation

cat <<EOF
---
  install complete, you still need to config the /etc/beaker/client.conf or
  ~/.beaker_client/config: fix value of USERNAME and do follow command:
    kinit ${kuser:-krb5_useranme}
    bkr whoami
EOF
