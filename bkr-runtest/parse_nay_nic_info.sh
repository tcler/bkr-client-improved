#!/bin/bash
# author: zhchen@redhat.com

progname=${0##*/}
exitcode=0

DRIVER=".*"
MODEL=".*"
MATCH=".*"
UNMATCH=""
SPEED=".*"
NUM=1
OUTPUT=hostname

search_nic_info()
{
	echo "$DRIVER"  | grep -qi "any" && DRIVER=".*"
	echo "$MODEL"   | grep -qi "any" && MODEL=".*"
	echo "$MATCH"	| grep -qi "any" && MATCH=".*"

	case "$SPEED" in
		any|ANY)	SPEED=".*" ;;
		1g|1G)		SPEED="1000" ;;
		10g|10G)	SPEED="10000" ;;
		40g|40G)	SPEED="40000" ;;
	esac

	awk 'BEGIN{IGNORECASE=1}; $0~/'"$MATCH"'/ &&
	$4~/\<'"$DRIVER"'\>/ && $6~/'"$MODEL"'/ && $7~/'"${SPEED}Mb"'/ '
}

filter_nic_match()
{
	# remove the item if the machine contains unwished match
	search_result=`cat -`
	if [ -n "$UNMATCH" ]; then
		matched_hostname=$(awk 'BEGIN{IGNORECASE=1}; $0 ~/'"$UNMATCH"'/ {printf "%s|", $3}' <<< "$search_result")
		matched_hostname_pattern="${matched_hostname%|}"
		if [ -n "$matched_hostname_pattern" ]; then
			search_result=$(egrep -v "$matched_hostname_pattern" <<< "$search_result")
		fi
	fi
	echo "$search_result"
}


filter_nic_num()
{
	# remove the item if the machine's matched NIC count is less than required
	search_result=`cat -`
	matched_hostname=$(awk '{print $3}' <<< "$search_result" | uniq -c | awk '{if ($1 >= '"$NUM"') printf "%s|", $2; }')
	matched_hostname_pattern="${matched_hostname%|}"
	[ ${#matched_hostname_pattern} -ne 0 ] && {
		egrep "$matched_hostname_pattern" <<< "$search_result"
	} || {
		>&2 echo "Error: no matched machine have $NUM required NIC(s)"
		let exitcode++
		exit $exitcode
	}
}

output_result()
{
	case "$OUTPUT" in
		hostname)
			awk '{print $3".rhts.eng.nay.redhat.com"}' | sort -u
			;;
		raw)
			cat -
			;;
		table)
			awk '{print $3" "$4" "$6" "$7}'| awk '
			BEGIN { i=1 }
			{
				column[i]=$0
				i++
			}
			END {
				t=1
				for (i=1; i<=NR; i++){
					if (column[i]==column[i+1]) {
						t++
						continue
					}
					printf "%s %s\n", column[i], t
					t=1
				}
			}
			' | column -t
			;;
		field)
			case "$FIELD" in
				host*|machine|name)	field='$3' ;;
				driver)			field='$4' ;;
				model)			field='$6' ;;
				speed)			field='$7' ;;
			esac
			awk '{print '"$field"'}' | sort -u
			;;
	esac
}

Usage()
{
	cat <<- END
	Utils to parse nic_info file - search required NICs and print customer items

	Search options:
	  -d, --driver		NIC driver
	  -m, --model		NIC model
	  -p, --match		customer pattern which match the regex (emulates "egrep")
	  -v, --unmatch		customer pattern which does NOT match the regex (emulates "egrep -v")
	  -s, --speed		NIC speed
	  -c, --num		at least how many matched NICs that the machine have
	  The results is the intersection of all specified conditions.

	Output options:
	  Print results wich meet NIC search requirements.
	  --hostname		print full hostname (default)
	  --raw 		print raw nic_info content
	  --table		print sort <host-nic> table, for viewing searching items
	  --field		print customer field, eg: hostname,driver,model,speed
	  --help		display this help text and exit

	Examples:
	  $progname --hostname --speed 10g --num 2 --match 'hp.*driver-Prototype' --unmatch 'cisco|mlx4|4550-xe'
	  $progname --hostname --driver mlx4_en --speed 10g
	  $progname --hostname --model bcm5719
	  $progname --hostname --match ibm
	  $progname --raw --driver "sfc|be2net"
	  $progname --table --speed 10g
	  $progname --field model --driver tg3

	END
}

_at=`getopt -o d:s:m:p:v:c:h \
	--long driver: \
	--long model: \
	--long match: \
	--long unmatch: \
	--long speed: \
	--long num: \
	--long field: \
	--long hostname \
	--long raw \
	--long table \
	--long help \
	-n "$progname" -- "$@"`
eval set -- "$_at"

while true; do
	case "$1" in
	-d|--driver)	DRIVER="$2"; shift 2;;
	-m|--model)	MODEL="$2"; shift 2;;
	-p|--match)	MATCH="$2"; shift 2;;
	-v|--unmatch)	UNMATCH="$2"; shift 2;;
	-s|--speed)	SPEED="$2"; shift 2;;
	-c|--num)	NUM="$2"; shift 2;;
	--field)	OUTPUT=field; FIELD="$2"; shift 2;;
	--hostname)	OUTPUT=hostname; shift 1;;
	--raw)		OUTPUT=raw; shift 1;;
	--table)	OUTPUT=table; shift 1;;
	-h|--help)	Usage; shift 1; exit 0;;
	--) shift; break;;
	esac
done

[ -n "$NIC_INFO" ] || {
	NIC_INFO=/tmp/nic_info
	NIC_INFO_URL=http://pkgs.devel.redhat.com/cgit/tests/kernel/plain/networking/inventory/nic_info
	wget -q $NIC_INFO_URL -O $NIC_INFO
}

set -o pipefail
sed 's/^#.*$//; /^$/d' $NIC_INFO | search_nic_info | filter_nic_match | filter_nic_num | output_result
[ $? -ne 0 ] && { echo "NULL"; let exitcode++; }
exit $exitcode
