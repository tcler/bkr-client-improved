#!/bin/bash
# this is a prototype about diff two test run

export LANG=C
P=${0##*/}
#-------------------------------------------------------------------------------
Usage() {
	echo "Usage: $P [-h|--help] [-r] [--db <dbfile>] [--bc] [--diff [-o ofile]]"
	echo "Options:"
	echo "  --bc                 #Use 'Beyond Compare' instead default vimdiff"
	echo "  --db </path/dbfile>  #Use specified dbfile, can use more than one time"
	echo "  --diff               #Use diff command"
	echo "  --diffr              #Alias: --diff -r"
	echo "  -o <ofile>           #Output file used to save output of --diff option"
	echo "  -r                   #Reverse the order of comparison"
	echo "Examples:"
	echo "  $P"
	echo "  $P -r --bc"
	echo "  $P --db ~/testrun.db.orig --diff"
	echo "  $P --db ~/testrun.db.orig --db ~/.testrundb/testrun.db --diff"
}

_at=`getopt -o hro: \
	--long help \
	--long db: \
	--long bc \
	--long diff \
	--long diffr \
    -a -n 'bkr-autorun-diff.sh' -- "$@"`
eval set -- "$_at"

dbs=()
runs=()
while true; do
	case "$1" in
	-h|--help)
		Usage; shift 1; exit 0;;
	-r)
		reverse=yes; shift 1;;
	--db)
		if [ -f "$2" ]; then
			dbs+=("$2");
		else
			echo "file '$2' not exist" >&2
			exit 1
		fi
		shift 2;;
	--bc)
		BC=yes; shift 1;;
	--diff)
		diffv=yes; shift 1;;
	--diffr)
		diffv=yes; reverse=yes; shift 1;;
	-o)
		OF=$2; shift 2;;
	--)
		shift; break;;
	esac
done

[[ ${#dbs[@]} = 0 ]] && dbs=(~/.testrundb/testrun.db)
for dbfile in "${dbs[@]}"; do
	dialogres=.$$.res
	eval dialog --backtitle "bkr-autorun-diff" --separate-output --checklist "testrun_list-$dbfile" 30 120 28  $(bkr-autorun-stat -r --db=$dbfile|sed 's/.*/"&" "" 1/')  2>$dialogres
	while read run; do
		runs+=("${dbfile}::${run}")
	done <$dialogres
	rm -f $dialogres
done

for run in "${runs[@]}"; do
	echo "$run"
done

[[ ${#runs[@]} < 2 ]] && {
	echo "{Error} you must select more than 1 testrun to diff" >&2
	exit
}

read dbfile1 run1 <<<"${runs[0]/::/ }"
read dbfile2 run2 <<<"${runs[1]/::/ }"
[[ "$reverse" = yes ]] && {
	read dbfile1 run1 <<<"${runs[1]/::/ }"
	read dbfile2 run2 <<<"${runs[0]/::/ }"
}
resf1=.${run1//[ \']/_}.$$.1.res
resf2=.${run2//[ \']/_}.$$.2.res

trap "sigproc" SIGINT SIGTERM SIGHUP SIGQUIT
sigproc() {
	rm -fr ${resf1}* ${resf2}* ${resf1%.res} ${resf2%.res}
	exit
}

eval bkr-autorun-stat --db=$dbfile1 --lsres ${run1}  >${resf1}
eval bkr-autorun-stat --db=$dbfile2 --lsres ${run2}  >${resf2}

if [[ -z "$diffv" ]]; then
	diff1=${resf1}-
	diff2=${resf2}-
	grep -v ^http ${resf1} >${diff1}
	grep -v ^http ${resf2} >${diff2}
	rm -f ${resf1} ${resf2}
	Diff=vimdiff
	[[ "$BC" = yes ]] && which bcompare && Diff=bcompare
	$Diff ${diff1} ${diff2}
	rm -f ${diff1} ${diff2}
else
	tmpf="${OF}.$$.diffs"
	mkdir ${resf1%.res} ${resf2%.res}
	id_list=$(awk '$1 == "TEST_ID:"{print $2}' ${resf1} ${resf2} | sort -u)
	for id in $id_list; do
		for f in ${resf1} ${resf2}; do
			awk "BEGIN{RS=\"\"} /$id/" $f | sed '/^http/d' >${f%.res}/$id
		done
		taskurl=$(grep $id ${resf1} ${resf2} -A2|sed -n -e 's/^\.[a-z0-9-]*__//' -e '/http/{s/_.[0-9]*.[12].res-/\n  /;p}')
		if ! cmp -s ${resf1%.res}/$id ${resf2%.res}/$id; then
			if egrep -q '^  (F|W|A)' ${resf2%.res}/$id; then
				diffres=$(diff -pNur ${resf1%.res}/$id ${resf2%.res}/$id)
				if grep -q '^+[^+]' <<<"$diffres"; then
					echo -e "\n#Test result different, and has New Fail"
					sed -n '2{s/^/=== /;p;q}' ${resf1%.res}/$id
					echo -e "$taskurl\n."
					echo "$diffres"
				else
					echo -e "\n#Test result different, but no New Fail"
					sed -n '2{s/^/=== /;p;q}' ${resf1%.res}/$id
					echo -e "$taskurl\n."
					echo "$diffres"
				fi
			fi
		elif egrep -q '^  (F|W|A)' ${resf1%.res}/$id; then
			echo -e "\n#Test result same, but Fail:"
			sed -n '2{s/^/=== /;p;q}' ${resf1%.res}/$id
			echo -e "$taskurl"
		fi
	done >"$tmpf"
	less "$tmpf"
	[[ -n "$OF" ]] && mv "$tmpf" "$OF" || rm -f "$tmpf"
	rm -rf $resf1 $resf2 ${resf1%.res} ${resf2%.res}
fi
