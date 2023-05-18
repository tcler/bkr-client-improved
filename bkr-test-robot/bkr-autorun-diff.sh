#!/bin/bash
# this is a prototype about diff two test run

export LANG=C
P=${0##*/}
#-------------------------------------------------------------------------------
Usage() {
	echo "Usage: $P [-h|--help] [-r] [-v] [--db <dbfile>] [--bc] [--diff [-o ofile [--override|--append]]] [--short]"
	echo "Options:"
	echo "  --bc                 #Use 'Beyond Compare' instead default vimdiff"
	echo "  --db </path/dbfile>  #Use specified dbfile, can use more than one time"
	echo "  --diff               #Use diff command"
	echo "  --diffr              #Alias: --diff -r"
	echo "  --noavc              #Ignore the avc failures (This implies option --diff)"
	echo "  --short              #Only print new failures of diff command (This implies option --diff)"
	echo "  --shortr             #Only print new failures of diff command in reverse order (Alias: --short -r)"
	echo "  -o <ofile>           #Output file used to save output of --diff option"
	echo "  --override           #Override it if the output file exists (along with '-o ofile')"
	echo "  --append             #Append to it if the output file exists (along with '-o ofile')"
	echo "  -r                   #Reverse the order of comparison"
	echo "  -v                   #Be verbose"
	echo "  -h|--help            #Show this help message"
	echo "Examples:"
	echo "  $P"
	echo "  $P -r --bc"
	echo "  $P --db ~/testrun.db.orig --diff"
	echo "  $P --db ~/testrun.db.orig --db ~/.testrundb/testrun.db --diff"
}

_at=`getopt -o hrvo: \
	--long help \
	--long db: \
	--long bc \
	--long diff \
	--long diffr \
	--long noavc \
	--long short \
	--long shortr \
	--long override \
	--long append \
    -a -n 'bkr-autorun-diff.sh' -- "$@"`
eval set -- "$_at"

dbs=()
runs=()
reverse=""
verbose=""
BC=""
diffv=""
noavc=""
short=""
OF=""
override=""
append=""
leave=""

while true; do
	case "$1" in
	-h|--help)
		Usage; shift 1; exit 0;;
	-r)
		reverse=yes; shift 1;;
	-v)
		verbose=yes; shift 1;;
	--db)
		dbs+=("$2"); shift 2;;
	--bc)
		BC=yes; shift 1;;
	--diff)
		diffv=yes; shift 1;;
	--diffr)
		diffv=yes; reverse=yes; shift 1;;
	--noavc)
		diffv=yes; noavc=yes; shift 1;;
	--short)
		diffv=yes; short=yes; shift 1;;
	--shortr)
		diffv=yes; short=yes; reverse=yes; shift 1;;
	-o)
		OF=$2; shift 2;;
	--override)
		override=yes; shift 1;;
	--append)
		append=yes; shift 1;;
	--)
		shift; break;;
	esac
done

[[ ${#dbs[@]} = 0 ]] && dbs=(~/.testrundb/testrun.db)
for dbfile in "${dbs[@]}"; do
	if [ ! -f "$dbfile" ]; then
		echo "{Error} cannot find db file $dbfile" >&2
		exit 1
	fi
	dialogres=.$$.res
	eval dialog --backtitle "bkr-autorun-diff" --separate-output --checklist "testrun_list-$dbfile" 30 120 28  $(bkr-autorun-stat -r --db=$dbfile|sed 's/.*/"&" "" 1/')  2>$dialogres
	while read run; do
		runs+=("${dbfile}::${run}")
	done <$dialogres
	rm -f $dialogres
done

[[ "$verbose" = yes ]] && {
	for run in "${runs[@]}"; do
		echo "$run"
	done
}

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
resf1=.${run1//[ \'\/]/_}.$$.1.res
resf2=.${run2//[ \'\/]/_}.$$.2.res

trap "sigproc" SIGINT SIGTERM SIGHUP SIGQUIT
sigproc() {
	rm -fr ${resf1}* ${resf2}* ${resf1%.res} ${resf2%.res}
	exit
}

eval bkr-autorun-stat --db=$dbfile1 --lsres ${run1}  >${resf1}
if [ ! -s "$resf1" ]; then
	echo "{Warn} No result found for the testrun $run1"
fi

eval bkr-autorun-stat --db=$dbfile2 --lsres ${run2}  >${resf2}
if [ ! -s "$resf2" ]; then
	echo "{Warn} No result found for the testrun $run2"
fi

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
	if [[ "$short" != "yes" ]]; then
		echo -e "# Dig diff of testrun: ${run2}" >"$tmpf"
	else
		echo -e "# New fail of testrun: ${run2}" >"$tmpf"
	fi
	echo -e "# Compared to testrun: ${run1}" >>"$tmpf"
	mkdir ${resf1%.res} ${resf2%.res}
	id_list=$(awk '$1 == "TEST_ID:"{print $2}' ${resf1} ${resf2} | sort -u)
	for id in $id_list; do
		for f in ${resf1} ${resf2}; do
			awk "BEGIN{RS=\"\"} /$id/" $f | sed '/^http/d' >${f%.res}/$id
		done
		taskurl=$(grep $id ${resf1} ${resf2} -A2|sed -n -e 's/^\.[a-z0-9-]*__//' -e '/http/{s/_.[0-9]*.[12].res-/\n  /;p}')
		if ! cmp -s ${resf1%.res}/$id ${resf2%.res}/$id; then
			if grep -E -q '^  (F|W|A|P)' ${resf2%.res}/$id; then
				diffres=$(diff -pNur ${resf1%.res}/$id ${resf2%.res}/$id)
				# ignore avc failures
				if [[ "$noavc" == "yes" ]]; then
					diffres=$(echo "$diffres" | sed '/avc.*Fail/d')
				fi
				if grep -E -q '^\+[^+].*(Warn|Fail|Panic|Abort)$' <<<"$diffres"; then
					if [[ "$short" != "yes" ]]; then
						echo -e "\n#Test result different, and has New Fail"
						sed -n '2{s/^/=== /;p;q}' ${resf1%.res}/$id
						echo -e "$taskurl\n."
						echo "$diffres"
					else
						sed -n '2{s/^/- /;p;q}' ${resf1%.res}/$id
					fi
				else
					if [[ "$short" != "yes" ]]; then
						echo -e "\n#Test result different, but no New Fail"
						sed -n '2{s/^/=== /;p;q}' ${resf1%.res}/$id
						echo -e "$taskurl\n."
						echo "$diffres"
					fi
				fi
			fi
		elif grep -E -q '^  (F|W|A|P)' ${resf1%.res}/$id; then
			if [[ "$short" != "yes" ]]; then
				echo -e "\n#Test result same, but Fail:"
				sed -n '2{s/^/=== /;p;q}' ${resf1%.res}/$id
				echo -e "$taskurl"
			fi
		fi
	done >>"$tmpf"
	if [[ "$short" != "yes" ]]; then
		less "$tmpf"
	else
		cat "$tmpf"
	fi
	if [[ -n "$OF" ]]; then
		if [[ -e "$OF" ]]; then
			# need decision: override, append or leave
			while [[ "$override" != "yes" && "$append" != "yes" && "leave" != "yes" ]]; do
				read -p "File '$OF' exists already. Do you want to override (o), append (a) or just leave (l) it? " answer
				case $answer in
				[Oo]* )
					override=yes
					echo "{INFO} Can use '--override' (along with '-o ofile') for non-interactive shell."
					break;;
				[Aa]* )
					append=yes
					echo "{INFO} Can use '--append' (along with '-o ofile') for non-interactive shell."
					break;;
				[Ll]* )
					leave=yes
					echo "{INFO} So you regret that '-o ofile' was used now :)"
					break;;
				* )
					echo "{WARN} Please answer override (o), append (a) or leave (l)."
					continue;;
				esac
			done
		else
			# just override if no original one
			override=yes
		fi
	else
		# just leave it if no output file specified
		leave=yes
	fi
	if [[ "$override" == "yes" ]]; then
		mv "$tmpf" "$OF"
	elif [[ "$append" == "yes" ]]; then
		cat "$tmpf" >> "$OF"
		rm -f "$tmpf"
	elif [[ "$leave" == "yes" ]]; then
		rm -f "$tmpf"
	else
		echo "{WARN} Something wrong occurs, should not be here."
	fi
	rm -rf $resf1 $resf2 ${resf1%.res} ${resf2%.res}
fi
