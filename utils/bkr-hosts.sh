#!/bin/bash

Usage() {
	echo "Usage: [wiki=1] $0 [-o <owner> | [FQDN1 FQDN2 ...]]" >&2
}

_at=`getopt -o ho: \
	--long help \
	--long owner: \
    -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help)   Usage; shift 1; exit 0;;
	-o|--owner)  owner=$2; shift 2;;
	--) shift; break;;
	esac
done

owner=${owner:-fs-qe}
hosts="$@"
[ -z "$hosts" ] && {
	hosts=$(bkr list-systems --xml-filter='<system><owner op="==" value="'"$owner"'"/></system>')
}

baseUrl=https://beaker.engineering.redhat.com

hostinfo() {
	local h=$1 wikiIdx=$2
	local sysinfo=$(curl -L -k -s $baseUrl/systems/$h);

	read memory cpu_cores cpu_processors cpu_speed disk_space status loanedTo _ < \
		<(jq '.|.memory,.cpu_cores,.cpu_processors,.cpu_speed,.disk_space,.status,.current_loan.recipient' <<<"$sysinfo" | xargs)

	notes=$(jq '.notes[]|select(.deleted == null)|.text' <<<"$sysinfo")
	wikiNote=$(echo "$notes" | sed -rne '/wiki_note: */{p}')
	brokenNote=$(echo "$notes" | sed -rne '/(Broken|Ticket): */{p}')

	if [[ -z "$wikiIdx" ]]; then
		echo $h;
		{
			echo "CPU: ${cpu_cores}/${cpu_processors}:${cpu_speed/.*/}"
			echo "Memory: $memory"
			echo "Condition: $status"
			[[ -n "$loanedTo" ]] && echo "LoanedTo: $loanedTo"
			[[ -n "$notes" ]] && echo -e "Notes: {\n$notes\n}"
		} | sed 's/^ */  /'
		echo
	else
		echo "||$wikiIdx||[[$baseUrl/view/$h|$h]]||${cpu_cores}/${cpu_processors}:${cpu_speed/.*/}||$memory||${status}||${loanedTo:--}||${wikiNote}||"
	fi
}

#wiki passed by ENV
[[ -n "$wiki" ]] &&
	echo "|| '''Idx''' || '''Hostname''' || '''CPU''' || '''Memory''' || '''Condition''' || '''Loaned''' || '''Notes''' ||"

i=1
for host in $hosts; do
	hostinfo $host ${wiki:+$((i++))}
done
