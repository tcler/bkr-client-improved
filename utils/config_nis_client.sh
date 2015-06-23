#!/bin/bash
#author: jiyin@redhat.com

export LANG=C
infoecho() { echo -e "\n${P:-DO ==>}" "\E[1;34m" "$@" "\E[0m"; }
errecho() { echo -e "\n${P:-DO ==>}" "\E[31m" "$@" "\E[0m"; }

[ $# = 0 ] && {
	echo "usage: $0  <nis server name>"
	exit 1
}

nisServ=$1
nisDomain=$(echo $nisServ|sed 's/^.*$/\U&/')
pkgs=yp-tools

infoecho "sure install $pkgs ..."
rpm -q $pkgs || yum -y install $pkgs

infoecho "enables nis auth, and set nis server info ..."
#authconfig  --updateall --enablenis --nisdomain=$nisDomain --nisserver=$nisServ
authconfig --nostart --updateall --enablenis --nisdomain=$nisDomain --nisserver=$nisServ

infoecho "debug: nisServ=$nisServ, nisDomain=$nisDomain"
rpcinfo -p $nisServ | grep -w ypserv

infoecho "show yp.conf ..."
grep '^[^#]' /etc/yp.conf

infoecho "show /etc/sysconfig/network ..."
cat /etc/sysconfig/network

infoecho "start ypbind ..."
service ypbind start

infoecho "ypcat test ..."
ypcat passwd

