#!/bin/bash
#author: jiyin@redhat.com

export LANG=C
infoecho() { echo -e "\n${P:-DO ==>}" "\E[1;34m" "$@" "\E[0m"; }
errecho() { echo -e "\n${P:-ERR ==>}" "\E[31m" "$@" "\E[0m"; }
KRB_CONF=/etc/krb5.conf
KDC_CONF=/var/kerberos/krb5kdc/kdc.conf
ACL_CONF=/var/kerberos/krb5kdc/kadm5.acl
pkgs="krb5-server krb5-workstation"
#realm=${1:-RHQE.COM}
realm=RHQE.COM
hostname `hostname -A 2>/dev/null | awk '{print $1}'`
host=$(hostname)

[ -z "$host" ] && {
	errecho "{WARN} There is no available host:name find. use local name instead."
	host=$(hostname -f)
	ping -c 3 "$host" || {
		errecho "{WARN} Can not ping hostname:'${host}', please ensure '$host' available."
		exit 1
	}
}

enctypes="aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal"
krbConfTemp="[logging]%N default = FILE:/var/log/krb5libs.log%N kdc = FILE:/var/log/krb5kdc.log%N admin_server = FILE:/var/log/kadmind.log%N%N[libdefaults]%N dns_lookup_realm = false%N ticket_lifetime = 24h%N renew_lifetime = 7d%N forwardable = true%N rdns = false%N default_realm = EXAMPLE.COM%N%N[realms]%N EXAMPLE.COM = {%N  kdc = kerberos.example.com%N  admin_server = kerberos.example.com%N }%N%N[domain_realm]%N .example.com = EXAMPLE.COM%N example.com = EXAMPLE.COM%N"
kdcConfTemp="[kdcdefaults]%N kdc_ports = 88%N kdc_tcp_ports = 88%N%N[realms]%N EXAMPLE.COM = {%N  #master_key_type = aes256-cts%N  acl_file = /var/kerberos/krb5kdc/kadm5.acl%N  dict_file = /usr/share/dict/words%N  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab%N  supported_enctypes = $enctypes%N }%N"
kadmAclTemp="*/admin@EXAMPLE.COM	*"

grep -q "$realm" "$KRB_CONF" 2>/dev/null && {
	echo "{INFO} kerberos was ready."
	exit 0
}

infoecho "clean old config and data ..."
#\cp $KRB_CONF ${KRB_CONF}.orig
kdestroy -A
\rm -f /etc/krb5.keytab  /var/kerberos/krb5kdc/principal* 
\rm -f /tmp/krb5cc*  /var/tmp/krb5kdc_rcache  /var/tmp/rc_kadmin_0
echo "$krbConfTemp"|sed 's/%N/\n/g' >$KRB_CONF
echo "$kdcConfTemp"|sed 's/%N/\n/g' >$KDC_CONF
echo "$kadmAclTemp"|sed 's/%N/\n/g' >$ACL_CONF
#===============================================================================

infoecho "make sure package $pkgs install ..."
rpm -q $pkgs || yum -y install $pkgs

#infoecho "open necessary firewall port ..."
echo <<COM
	iptables -A RHS333 -p udp --dport 88 -j ACCEPT
	iptables -A RHS333 -p tcp --dport 88 -j ACCEPT
	iptables -A RHS333 -p udp --dport 464 -j ACCEPT
	iptables -A RHS333 -p tcp --dport 749 -j ACCEPT
	service iptables save
COM

infoecho "close the firewall  ..."
service iptables stop
which systemctl &>/dev/null && systemctl stop firewalld

infoecho "configure '$KRB_CONF' ..."
sed -r -i -e 's;^#+;;' -e "/EXAMPLE.COM/{s//$realm/g}" -e "/kerberos.example.com/{s//$host/g}"   $KRB_CONF
sed -r -i -e "/ (\.)?example.com/{s// \1${host#*.}/g}"   $KRB_CONF

infoecho "create and initialize the Kerberos database on KDC"
#( set +m; if=/dev/urandom of=/dev/random count=1024000 & )
mv  /dev/random  /dev/random.orig
ln -s /dev/urandom  /dev/random
(echo "redhat"; usleep 100000; echo "redhat") | kdb5_util create -r $realm -s
mv /dev/random.orig /dev/random
infoecho "configure '$KDC_CONF' '$ACL_CONF' ..."
sed -i -e "/EXAMPLE.COM/{s//$realm/g; s/^ *#+//}"   $KDC_CONF $ACL_CONF

infoecho "add principal root/admin and users ..."
princList="root/admin,redhat 
	root,redhat
	krbAccount,redhat
	krbuser0,pkrbuser0 krbuser1,pkrbuser1 krbuser2,pkrbuser2 krbuser3,pkrbuser3
	krbuser4,pkrbuser4 krbuser5,pkrbuser5 krbuser6,pkrbuser6 krbuser7,pkrbuser7"
for kv in $princList; do
	read  princ pass nil <<<"${kv//,/ }"
	kadmin.local -q "addprinc -pw $pass $princ"
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

infoecho "add root and krbAccount to keytab ..."
kadmin.local -q "ktadd  root"

infoecho "========Conf finish========"
infoecho "========Test kadmin========"
sleep 10
loop=10
for ((i=0; i<loop; i++)); do
	(echo -e "redhat\nlistprincs\nq\n") | kadmin && break
	sleep 1
done
if [ $i -ge $loop ]; then
	errecho "Test FAIL"
	exit 1
else
	infoecho "Test OK"
fi

infoecho "test the /etc/krb5.keytab ..."
klist -e -k -t /etc/krb5.keytab

