#!/bin/bash

#Usage
#[wiki=1] bkr-hosts.sh [$owner]

owner=${1:-fs-qe}
baseUrl=https://beaker.engineering.redhat.com

hostinfo() {
	local h=$1 wikiIdx=$2
	local sysinfo=$(curl -L -k -s $baseUrl/systems/$h);

	: <<-END
	memory=$(echo "$sysinfo" | sed -nr '/memory/{s/.*: //;s/,$//;p}');
	cpu_cores=$(echo "$sysinfo" | sed -n '/cpu_cores/{s/.*: //;s/,$//;p}');
	cpu_processors=$(echo "$sysinfo" | sed -n '/cpu_processors/{s/.*: //;s/,$//;p}');
	cpu_speed=$(echo "$sysinfo" | sed -n '/cpu_speed/{s/.*: //;s/,$//;p}');
	disk_space=$(echo "$sysinfo" | sed -n '/disk_space/{s/.*: //;s/,$//;p}');
	status=$(echo "$sysinfo" | sed -n '/"status":/{s/.*: //;s/[,"]//g;p}');
	END
	veval=$(echo "$sysinfo" | sed -nr '/memory|cpu_cores|cpu_processors|cpu_speed|disk_space|"status"/{s/[," ]//g;s/:/=/; p}');
	eval $veval

	loanedTo=$(echo "$sysinfo" | sed -ne '/"current_loan": {/ { :loop /recipient/! {N; b loop}; s/.*: //; s/[,"]//g; p'});
	notes=$(curl -s -u : -L "$baseUrl/view/$h#notes" |
		sed -ne '/<tr id="note_/ { :loop /<\/p>/! {N; b loop}; s/.*<p>//; s/<\/p>.*//; /wiki_note: */{s///;p}}')

	if [[ -z "$wikiIdx" ]]; then
		echo $h;
		{
			echo "CPU: ${cpu_cores}/${cpu_processors}:${cpu_speed/.*/}"
			echo "Memory: $memory"
			echo "Condition: $status"
			[[ -n "$loanedTo" ]] && echo "LoanedTo: $loanedTo"
			[[ -n "$notes" ]] && echo "Note: $notes"
		} | sed 's/^ */  /'
		echo
	else
		echo "||$wikiIdx||[[$baseUrl/view/$h|$h]]||${cpu_cores}/${cpu_processors}:${cpu_speed/.*/}||$memory||${status}||${loanedTo:--}||${notes}||"
	fi
}

#wiki passed by ENV
[[ -n "$wiki" ]] &&
	echo "|| '''Idx''' || '''Hostname''' || '''CPU''' || '''Memory''' || '''Condition''' || '''Loaned''' || '''Notes''' ||"

i=1
for host in $(bkr list-systems --xml-filter='<system><owner op="==" value="'"$owner"'"/></system>'); do
	hostinfo $host ${wiki:+$((i++))}
done
