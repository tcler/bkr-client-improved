#!/bin/bash
#author: jiyin@redhat.com

P=${0##*/}
family=
tag=rtt

Usage() {
	echo "Usage: $P [-f <3|4|5[s]|5c|6|7|alt-7|8|full-family-name>] [-t <rtt|stb|rel|ins|act|full-tag-name>] [-n distro-name-filter]"
	echo "  e.g: $P -f alt7 -t rtt"
	echo "  e.g: $P -f 7 -t rel -n %7.2"
}
_at=`getopt -o hdf:t:n: \
	--long help \
	--long debug \
	--long family: \
	--long tag: \
	--long name: \
    -a -n "$P" -- "$@"`
eval set -- "$_at"

while true; do
	case "$1" in
	-h|--help)      Usage; shift 1; exit 0;;
	-d|--debug)	debug=1; shift 1;;
	-f|--family)    family=$2; shift 2;;
	-t|--tag)       tag=$2; shift 2;;
	-n|--name)      name=$2; shift 2;;
	--) shift; break;;
	esac
done

[[ -z "$family" && -n "$1" ]] && family=$1
[[ -z "$tag" && -n "$2" ]] && tag=$2

case $family in
alt7|alt-7)	family=RedHatEnterpriseLinuxAlternateArchitectures7;;
3|4|6|7|8)	family=RedHatEnterpriseLinux$family;;
5s|5)		family=RedHatEnterpriseLinuxServer5;;
5c)		family=RedHatEnterpriseLinuxClient5;;
[0-9].*)	name=RHEL-$family; family=;;
*)		:;;
esac
case $tag in
all)	tag=;;
rtt)	tag=RTT_ACCEPTED;;
stb)	tag=STABLE;;
rel)	tag=RELEASED;;
ins)	tag=INSTALLS;;
act)	tag=Active;;
*)	:;;
esac

TagOption=
FamilyOption=
[[ -n "$tag" ]] && TagOption=--tag=$tag
[[ -n "$family" ]] && FamilyOption=--family=$family
[[ -n "$name" ]] && NameOption=--name=$name
[[ -n "$debug" ]] && echo "[debug] args: $TagOption $FamilyOption" >&2

if [[ ${P} != getLatestRHEL ]]; then
	bkr distros-list --limit=0 $TagOption $FamilyOption $NameOption 2>/dev/null > >(sed -n '/^ *Name: /{s///;p}')
else
	bkr distros-list --limit=0 $TagOption $FamilyOption $NameOption 2>/dev/null > >(sed -n '/^ *Name: /{s///;p}' | head -n1)
fi
