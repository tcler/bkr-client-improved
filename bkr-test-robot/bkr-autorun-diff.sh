#!/bin/bash
# this is a prototype about diff two test run

export LANG=C
P=${0##*/}
#-------------------------------------------------------------------------------
Usage() {
	echo "Usage: $P [-h|--help] [--db <dbfile>]"
}
_at=`getopt -o h \
	--long help \
	--long db: \
    -n 'bkr-autorun-diff.sh' -- "$@"`
eval set -- "$_at"

while true; do
	case "$1" in
	-h|--help)  Usage; shift 1; exit 0;;
	--db)       dbfile=$2; shift 2;;
	--) shift; break;;
	esac
done

dialogres=.$$.res
eval dialog --backtitle "Checklist" --checklist "Test" 30 120 28  $(bkr-autorun-stat -r --db=$dbfile|sed 's/.*/"&" "" 1/')  2>$dialogres
oIFS=$IFS; IFS=$'\n' runs=($(eval set -- $(< $dialogres); for v; do echo "$v"; done)); IFS=$oIFS
rm -f $dialogres

echo ${runs[0]}
echo ${runs[1]}

vimdiff <(eval bkr-autorun-stat --db=$dbfile --lsres ${runs[0]}) <(eval bkr-autorun-stat --db=$dbfile --lsres ${runs[1]})
