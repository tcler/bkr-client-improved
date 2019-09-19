#!/bin/bash

P=${0##*/}
Usage() {
	echo "Usage: $P  <comma separated user list>"
}
_at=`getopt -o hd \
	--long help \
    -n 'needinfome' -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help)      Usage; shift 1; exit 0;;
	-d)		DEBUG=yes; shift 1;;
	--) shift; break;;
	esac
done

users=${1}
[ -z "$users" ] && users=$(klist | awk -F'[@: ]+' '/^Default principal/{print $3}')
[ -z "$users" ] && {
	echo "U must specify a user or comma separated user list" >&2
}

searchUrl="https://bugzilla.redhat.com/buglist.cgi?classification=Red%20Hat&f1=requestees.login_name&list_id=10508602&o1=substring&query_format=advanced&v1="
for user in $users; do
	echo user:$user
	bugzilla query --from-url="$searchUrl"$user
	echo
done
