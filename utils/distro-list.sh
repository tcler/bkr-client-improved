#!/bin/bash
#author: jiyin@redhat.com

P=${0##*/}
family=
tag=rtt

Usage() {
	echo "Usage: $P [-f <3|4|5[s]|5c|6|7|alt7|8|full-family-name>] [-t <rtt|stb|rel|ins|act|full-tag-name>]"
	echo "  e.g: $P -f alt7 -t rtt"
}
_at=`getopt -o hdf:t: \
	--long help \
	--long debug \
	--long family: \
	--long tag: \
    -n "$P" -- "$@"`
eval set -- "$_at"

while true; do
	case "$1" in
	-h|--help)      Usage; shift 1; exit 0;;
	-d|--debug)	debug=1; shift 1;;
	-f|--family)    family=$2; shift 2;;
	-t|--tag)       tag=$2; shift 2;;
	--) shift; break;;
	esac
done

[[ -z "$family" && -n "$1" ]] && family=$1
[[ -z "$tag" && -n "$2" ]] && tag=$2

case $family in
3|4|6|7|8) family=RedHatEnterpriseLinux$family;;
alt7)	family=RedHatEnterpriseLinuxAlternateArchitectures7;;
5c)	family=RedHatEnterpriseLinuxClient5;;
5s|5)	family=RedHatEnterpriseLinuxServer5;;
*)	:;;
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
[[ -n "$debug" ]] && echo "[debug] args: $TagOption $FamilyOption" >&2

if [[ ${P} != getLatestRHEL ]]; then
	bkr distros-list --limit=0 $TagOption $FamilyOption | sed -n '/^ *Name: /{s///;p}'
else
	bkr distros-list --limit=0 $TagOption $FamilyOption | sed -n '/^ *Name: /{s///;p}' | head -n1
fi
