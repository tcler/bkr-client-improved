#!/bin/bash
# this is a prototype about diff two test run

export LANG=C
P=${0##*/}
#-------------------------------------------------------------------------------
Usage() {
	echo "Usage: $P [-h|--help] [--bc] [--db <dbfile>]"
	echo "Options:"
	echo "  --bc                 #Use beyond compare as diff tool"
	echo "  --db </path/dbfile>  #Use specified dbfile"
}
_at=`getopt -o h \
	--long help \
	--long db: \
	--long bc \
    -n 'bkr-autorun-diff.sh' -- "$@"`
eval set -- "$_at"

while true; do
	case "$1" in
	-h|--help)  Usage; shift 1; exit 0;;
	--db)       dbfile=$2; shift 2;;
	--bc)       BC=yes; shift 1;;
	--) shift; break;;
	esac
done

dialogres=.$$.res
eval dialog --backtitle "bkr-autorun-diff" --checklist "testrun_list" 30 120 28  $(bkr-autorun-stat -r --db=$dbfile|sed 's/.*/"&" "" 1/')  2>$dialogres
oIFS=$IFS; IFS=$'\n' runs=($(eval set -- $(< $dialogres); for v; do echo "$v"; done)); IFS=$oIFS
rm -f $dialogres

echo ${runs[0]}
echo ${runs[1]}
[[ ${#runs[@]} < 2 ]] && {
	echo "{Error} you must select more than 1 testrun to diff" >&2
	exit
}

resfile0=.${runs[0]//[ \']/_}.$$.res0
resfile1=.${runs[1]//[ \']/_}.$$.res1
eval bkr-autorun-stat --db=$dbfile --lsres ${runs[0]} >$resfile0
eval bkr-autorun-stat --db=$dbfile --lsres ${runs[1]} >$resfile1
Diff=vimdiff
[[ "$BC" = yes ]] && which bcompare && Diff=bcompare
$Diff $resfile0 $resfile1
rm -f $resfile0 $resfile1
