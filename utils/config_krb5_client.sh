#!/bin/bash
#author: jiyin@redhat.com

export LANG=C
infoecho() { echo -e "\n${P:-DO ==>}" "\E[1;34m" "$@" "\E[0m"; }
errecho() { echo -e "\n${P:-DO ==>}" "\E[31m" "$@" "\E[0m"; }
KRB_CONF=/etc/krb5.conf
krbServ=$1
realm=RHQE.COM
pkgs=krb5-workstation
ccache_name=
keyringcache=$2
[ -n "$keyringcache" ] && ccache_name="default_ccache_name = KEYRING:persistent:%{uid}"

krbConfTemp="[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_realm = EXAMPLE.COM
 $ccache_name

[realms]
 EXAMPLE.COM = {
  kdc = kerberos.example.com
  admin_server = kerberos.example.com
 }

[domain_realm]
 .example.com = EXAMPLE.COM
 example.com = EXAMPLE.COM"

[ $# = 0 ] && {
	echo "usage: $0  <krb5 server address>"
	exit 1
}
[ -z "$krbServ" ] && {
	echo "{WARN} something is wrong! can not get the krb server addr."
	exit 1
}
ping -c 4 $krbServ || {
	echo "{WARN} can not cennect krb server '$krbServ'."
	exit 1
}
rpm -q telnet || yum -y install telnet
echo -e "\[" | telnet $krbServ 88 2>&1 | egrep 'Escape character is' || {
	echo "{WARN} krb port $krbServ:88 can not connect. please check the firewall of both point"
	exit 1
}

infoecho "make sure package $pkgs install ..."
rpm -q $pkgs || yum -y install $pkgs

if test "$HOSTNAME" != "$krbServ"; then
	infoecho "clean old config and data ..."
	kdestroy -A
	\rm -f /etc/krb5.keytab
	\rm -f /tmp/krb5cc*  /var/tmp/krb5kdc_rcache  /var/tmp/rc_kadmin_0
	echo "$krbConfTemp" >$KRB_CONF
else
	infoecho "$KRB_CONF has configed ..."
fi
#===============================================================================
infoecho "close the firewall ..."
[ -f /etc/init.d/iptables ] && service iptables stop
which systemctl &>/dev/null && systemctl stop firewalld

infoecho "configure '$KRB_CONF', edit the realm name ..."
sed -r -i -e 's;^#+;;' -e "/EXAMPLE.COM/{s//$realm/g}" -e "/kerberos.example.com/{s//$krbServ/g}"   $KRB_CONF
sed -r -i -e "/ (\.)?example.com/{s// \1${krbServ#*.}/g}"   $KRB_CONF
cat $KRB_CONF

infoecho "test connect to KDC with kadmin ..."
kadmin -p root/admin -w redhat -q "listprincs"

infoecho "create nfs princs and ext keytab ..."
host=$HOSTNAME
nfsprinc=nfs/${host}
kadmin -p root/admin -w redhat -q "addprinc -randkey $nfsprinc"
kadmin -p root/admin -w redhat -q "ktadd -k /etc/krb5.keytab $nfsprinc"

infoecho "create cifs princs and ext keytab ..."
cifsprinc=cifs/${host}
kadmin -p root/admin -w redhat -q "addprinc -pw redhat  $cifsprinc"
kadmin -p root/admin -w redhat -q "ktadd $cifsprinc"

infoecho "test the /etc/krb5.keytab ..."
sleep 5
klist -e -k -t /etc/krb5.keytab

infoecho "fetch tickit: kinit -k  ..."
kinit -k $cifsprinc
kinit -k $nfsprinc
echo redhat | kinit root
