#!/bin/bash
# this is a prototype about diff two test run

export LANG=C
P=${0##*/}
#-------------------------------------------------------------------------------
Usage() {
	echo "Usage: $P [-h|--help] [-r] [--bc] [--db <dbfile>]"
	echo "Options:"
	echo "  --bc                 #Use beyond compare as diff tool"
	echo "  --db </path/dbfile>  #Use specified dbfile"
}
_at=`getopt -o hr \
	--long help \
	--long db: \
	--long bc \
	--long diff \
    -a -n 'bkr-autorun-diff.sh' -- "$@"`
eval set -- "$_at"

while true; do
	case "$1" in
	-h|--help)  Usage; shift 1; exit 0;;
	-r)         reverse=yes; shift 1;;
	--db)       dbfile=$2; shift 2;;
	--bc)       BC=yes; shift 1;;
	--diff)     diffv=yes; shift 1;;
	--) shift; break;;
	esac
done

dialogres=.$$.res
eval dialog --backtitle "bkr-autorun-diff" --checklist "testrun_list" 30 120 28  $(bkr-autorun-stat -r --db=$dbfile|sed 's/.*/"&" "" 1/')  2>$dialogres
oIFS=$IFS; IFS=$'\n' runs=($(eval set -- $(< $dialogres); for v; do echo "$v"; done|sort -V)); IFS=$oIFS
rm -f $dialogres

echo ${runs[0]}
echo ${runs[1]}
[[ ${#runs[@]} < 2 ]] && {
	echo "{Error} you must select more than 1 testrun to diff" >&2
	exit
}

resf1=.${runs[0]//[ \']/_}.$$.res
resf2=.${runs[1]//[ \']/_}.$$.res
[[ "$reverse" = yes ]] && {
	resf1=.${runs[1]//[ \']/_}.$$.res
	resf2=.${runs[0]//[ \']/_}.$$.res
}
eval bkr-autorun-stat --db=$dbfile --lsres ${runs[0]}  >${resf1}
eval bkr-autorun-stat --db=$dbfile --lsres ${runs[1]}  >${resf2}

if [[ -z "$diffv" ]]; then
	diff1=${resf1}-
	diff2=${resf2}-
	grep -v ^http ${resf1} >${diff1}
	grep -v ^http ${resf2} >${diff2}
	Diff=vimdiff
	[[ "$BC" = yes ]] && which bcompare && Diff=bcompare
	$Diff ${diff1} ${diff2}
	rm -f ${diff1} ${diff2}
else
	mkdir ${resf1%.res} ${resf2%.res}
	id_list=$(awk '$1 == "TEST_ID:"{print $2}' ${resf1} ${resf2} | sort -u)
	for id in $id_list; do
		for f in ${resf1} ${resf2}; do
			awk "BEGIN{RS=\"\"} /$id/" $f | sed '/^http/d' >${f%.res}/$id
		done
		taskurl=$(grep $id ${resf1} ${resf2} -A2|sed -n -e '/http/{s/_.[0-9]*.res-/\n  /;p}')
		if ! cmp -s ${resf1%.res}/$id ${resf2%.res}/$id; then
			echo -e "\n----------------------------------------"
			echo "Test result different:"
			echo "$taskurl"
			diff -pNur ${resf1%.res}/$id ${resf2%.res}/$id
		elif egrep -q '^  (F|W|A)' ${resf1%.res}/$id ${resf2%.res}/$id; then
			echo -e "\n----------------------------------------"
			echo "Test result same, but fail:"
			echo "$taskurl"
		fi
	done | less
	rm -rf $resf1 $resf2 ${resf1%.res} ${resf2%.res}
fi
