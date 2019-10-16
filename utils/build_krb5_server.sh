#!/bin/bash
#author: jiyin@redhat.com

export LANG=C
infoecho() { echo -e "\n${P:-DO ==>}" "\E[1;34m" "$@" "\E[0m"; }
errecho() { echo -e "\n${P:-ERR ==>}" "\E[31m" "$@" "\E[0m"; }
KRB_CONF=/etc/krb5.conf
KDC_CONF=/var/kerberos/krb5kdc/kdc.conf
ACL_CONF=/var/kerberos/krb5kdc/kadm5.acl
pkgs="krb5-server krb5-workstation"
realm=RHQE.COM
hostname `hostname -A 2>/dev/null | awk '{print $1}'`
host=$(hostname)
ccache_name=
enctypes_all="aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal"
enctypes_supported=

Usage() {
	echo "Usage: $0 [-h] [-k|--keyringcache] [-e|--enctypes <all|key:salt>]"
	cat << END

Options:
  -h				print this usage
  -k|--keyringcache		use keyringcache
  -e|--enctypes <all|key:salt>	set supported_enctypes as all key:salt strings or some specified
END
}

# param parse
_at=`getopt -o hke: \
    --long keyringcache \
    --long enctypes: \
    -n "$0" -- "$@"`
eval set -- "$_at"

while true; do
	case "$1" in
	-h) Usage; shift 1; exit 0;;
	-k|--keyringcache) keyringcache=yes; shift;;
	-e|--enctypes) [ "$2" = all ] && enctypes_supported="$enctypes_all" || enctypes_supported="$2"; shift 2;;
	--) shift 1; break;;
	esac
done

[ "$keyringcache" = "yes" ] && ccache_name="default_ccache_name = KEYRING:persistent:%{uid}"

[ -z "$host" ] && {
	errecho "{WARN} There is no available host:name find. use local name instead."
	host=$(hostname -f)
	ping -c 3 "$host" || {
		errecho "{WARN} Can not ping hostname:'${host}', please ensure '$host' available."
		exit 1
	}
}

krbConfTemp="[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
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
kdcConfTemp="[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 EXAMPLE.COM = {
  #master_key_type = aes256-cts
  max_renewable_life = 7d 0h 0m 0s
  acl_file = /var/kerberos/krb5kdc/kadm5.acl
  dict_file = /usr/share/dict/words
  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
  #supported_enctypes = $enctypes_supported
  default_principal_flags = +renewable, +forwardable, +preauth
 }"
kadmAclTemp="*/admin@EXAMPLE.COM	*"

grep -q "$realm" "$KRB_CONF" && grep -q "$host" "$KDC_CONF" && grep -q "$realm" "$ACL_CONF" && {
	echo "{INFO} Has already been configured as Kerberos Server."
	echo "{INFO} If want to re-configure it anyway, please clear $KRB_CONF, $KDC_CONF, $ACL_CONF, etc."
	infoecho "start KDC daemons ..."
	chkconfig krb5kdc on; chkconfig kadmin on;
	service krb5kdc restart || errecho "start krb5kdc failed.\n"
	service kadmin restart  || errecho "start kadmin failed.\n"
	exit 0
}

infoecho "make sure package $pkgs install ..."
rpm -q $pkgs || yum -y install $pkgs

infoecho "clean old config and data ..."
#\cp $KRB_CONF ${KRB_CONF}.orig
kdestroy -A
\rm -f /etc/krb5.keytab  /var/kerberos/krb5kdc/principal* 
\rm -f /tmp/krb5cc*  /var/tmp/krb5kdc_rcache  /var/tmp/rc_kadmin_0
echo "$krbConfTemp" >$KRB_CONF
echo "$kdcConfTemp" >$KDC_CONF
echo "$kadmAclTemp" >$ACL_CONF
#===============================================================================

#infoecho "open necessary firewall port ..."
echo <<COM
	iptables -A RHS333 -p udp --dport 88 -j ACCEPT
	iptables -A RHS333 -p tcp --dport 88 -j ACCEPT
	iptables -A RHS333 -p udp --dport 464 -j ACCEPT
	iptables -A RHS333 -p tcp --dport 749 -j ACCEPT
	service iptables save
COM

infoecho "close the firewall  ..."
[ -f /etc/init.d/iptables ] && service iptables stop
which systemctl &>/dev/null && systemctl stop firewalld

infoecho "configure '$KRB_CONF' ..."
sed -r -i -e 's;^#+;;' -e "/EXAMPLE.COM/{s//$realm/g}" -e "/kerberos.example.com/{s//$host/g}"   $KRB_CONF
sed -r -i -e "/ (\.)?example.com/{s// \1${host#*.}/g}"   $KRB_CONF
cat $KRB_CONF

infoecho "configure '$KDC_CONF' ..."
sed -i -e "/EXAMPLE.COM/{s//$realm/g; s/^ *#+//}"   $KDC_CONF
[ -n "$enctypes_supported" ] && sed -i -e "/supported_enctypes/{s/^ *#/  /}" $KDC_CONF
cat $KDC_CONF

infoecho "configure '$ACL_CONF' ..."
sed -i -e "/EXAMPLE.COM/{s//$realm/g; s/^ *#+//}"   $ACL_CONF
cat $ACL_CONF

infoecho "create and initialize the Kerberos database on KDC"
#( set +m; if=/dev/urandom of=/dev/random count=1024000 & )
mv  /dev/random  /dev/random.orig
ln -s /dev/urandom  /dev/random
(echo "redhat"; sleep 0.1; echo "redhat") | kdb5_util create -r $realm -s
mv /dev/random.orig /dev/random

infoecho "add principal root/admin and users ..."
princList="root/admin,redhat 
	root,redhat
	krbAccount,redhat
	krbuser0,pkrbuser0 krbuser1,pkrbuser1 krbuser2,pkrbuser2 krbuser3,pkrbuser3
	krbuser4,pkrbuser4 krbuser5,pkrbuser5 krbuser6,pkrbuser6 krbuser7,pkrbuser7"
for kv in $princList; do
	read  princ pass nil <<<"${kv//,/ }"
	while ! kadmin.local -q "addprinc -pw $pass $princ"; do sleep 1; done
done
kadmin.local -q "listprincs"
[ $? != 0 ] && errecho "kadmin.local fail. something is wrong."

infoecho "start KDC daemons ..."
chkconfig krb5kdc on; chkconfig kadmin on;
service krb5kdc restart || errecho "start krb5kdc failed.\n"
service kadmin restart  || errecho "start kadmin failed.\n"

infoecho "create host principal for KDC and extract to keytab ..."
kadmin.local -q "addprinc -randkey  host/$host"
kadmin.local -q "ktadd  host/$host"

infoecho "========Conf finish========"
infoecho "========Test kadmin========"
sleep 10
loop=25
for ((i=0; i<loop; i++)); do
	kadmin -p root/admin -w redhat -q listprincs && break
	sleep 2
done
if [ $i -ge $loop ]; then
	errecho "Test FAIL"
	exit 1
else
	infoecho "Test OK"
fi

infoecho "test the /etc/krb5.keytab ..."
sleep 5
klist -e -k -t /etc/krb5.keytab

