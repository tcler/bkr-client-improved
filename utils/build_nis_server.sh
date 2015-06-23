#!/bin/bash
#author: jiyin@redhat.com

export LANG=C
infoecho() { echo -e "\n${P:-DO ==>}" "\E[1;34m" "$@" "\E[0m"; }
errecho() { echo -e "\n${P:-ERR ==>}" "\E[31m" "$@" "\E[0m"; }

YP_CONF=/etc/
NET_CONF=/etc/sysconfig/network
ypServ=$(hostname -A 2>/dev/null || hostname -f)
ypServ=${ypServ%% *}
pkgs="ypserv setup"
PATH=$PATH:/usr/lib64/yp:/usr/lib/yp
#===============================================================================
infoecho "sure install $pkgs ..."
service ypserv stop &>/dev/null
rpm -q $pkgs || yum -y install $pkgs
test -f /etc/shadow  || cp /etc/shadow-  /etc/shadow
test -f /etc/gshadow || cp /etc/gshadow- /etc/gshadow

infoecho "sure rpcbind start ..."
{ service portmap start; chkconfig portmap on; } 2>/dev/null
service rpcbind start

infoecho "close the firewall ..."
service iptables stop
which systemctl &>/dev/null && systemctl stop firewalld

infoecho "config $NET_CONF ..."
sed -i '/YPSERV_ARGS/d' $NET_CONF
echo 'YPSERV_ARGS="-p 808"' >>$NET_CONF
echo "NISDOMAIN=$ypServ" >>$NET_CONF

infoecho "set NIS domain name ..."
nisdomainname $(echo $ypServ|sed 's/^.*$/\U&/')

infoecho "start ypserver ..."
chkconfig ypserv on 2>/dev/null
service ypserv start

infoecho "initialize the NIS maps ..."
echo -e "\ny" | ypinit -m

infoecho "rpcinfo ..."
rpcinfo -s $ypServ 2>/dev/null || rpcinfo -p $ypServ

infoecho "add test users ..."
userList="nisuser0,pnisuser0 nisuser1,pnisuser1 nisuser2,pnisuser2 nisuser3,pnisuser3
nisuser4,pnisuser4 nisuser5,pnisuser5 nisuser6,pnisuser6 nisuser7,pnisuser7"
for kv in $userList; do
	read  user pass nil <<<"${kv//,/ }"
	useradd "$user"
	(echo "$pass"; usleep 100000; echo "$pass") | passwd $user
done

infoecho "make ... ... ..."
make -C /var/yp

