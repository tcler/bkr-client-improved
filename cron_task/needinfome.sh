#!/bin/bash

P=${0##*/}
Usage() {
	echo "Usage: $P [-e]  <User needinfo to>  [QA Contact]"
}
_at=`getopt -o hed \
	--long help \
    -n 'needinfome' -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help)      Usage; shift 1; exit 0;;
	-e)		EMAIL=yes; shift 1;;
	-d)		DEBUG=yes; shift 1;;
	--) shift; break;;
	esac
done

user=${1}
[ -z "$user" ] && user=$(klist | awk -F'[@: ]+' '/^Default principal/{print $3}')
[ -z "$user" ] && {
	echo "U must specify a user id" >&2
}
q=$2
[ -n "${q}" ] && Q="-q ${q}"

echo user:$user
echo
#bugzilla query -t NEW,ASSIGNED,POST,MODIFIED,ON_QA,VERIFIED,RELEASE_PENDING -i -q fs-qe --outputformat="%{id}: %{product}:%{component}:%{sub_component} - %{qa_contact} - %{bug_status} - %{summary}" -p "Red Hat Enterprise Linux 7"  -t ASSIGNED,POST,MODIFIED,ON_QA
componentList="kernel e2fsprogs e4fsprogs xfsprogs xfsdump btrfs-progs nfs-utils nfs-utils-lib nfs4-acl-tools libnfsidmap autofs cifs-utils rpcbind libtirpc system-storage-manager fedfs-utils gssproxy nfstest nfsometer fuse fuseiso cachefilesd"
for C in $componentList; do
	buglist+=$'\n'"$(bugzilla query --flag=needinfo? -t NEW,ASSIGNED,POST,MODIFIED,ON_QA,VERIFIED,RELEASE_PENDING -i -c $C $Q 2>/dev/null)"
done

[ "$DEBUG" = yes ] && echo -e "  " $buglist "\n"

for b in $buglist; do
	bugzilla query -b $b --raw 2>/dev/null | egrep -q "'requestee': '$user@redhat.com', 'status': '\?', 'name': 'needinfo'" && {
		bugzilla query -b $b --outputformat="%{product}:%{component}:%{sub_component} - %{qa_contact} - %{bug_status} - %{summary}"
		echo "    https://bugzilla.redhat.com/show_bug.cgi?id=$b"
		echo
	}
done | tee /tmp/needinfome-$user.out

[ "$EMAIL" = yes ] && grep 'https://bugzilla' /tmp/needinfome-$user.out && {
	[ -n "$q" ] && q+=@redhat.com
	cat /tmp/needinfome-$user.out | sendmail.sh -p '[Remind needinfo fs-qe@] ' -t "$q" -c "fs-qe-dev@redhat.com" - \
		"There's one or more bug with 'fs-qe needinfo' flag"  &>/dev/null
}
