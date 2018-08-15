
winVer=${1:-2012}

echo -e "Info: checking dependence ..."
which nc &>/dev/null || dep=nmap-ncat
which vncviewer &>/dev/null || dep+=\ realvnc-vnc-viewer
[[ -n $dep ]] && {
	echo "Warn: you need install $dep first, try:" >&2
	echo "    sudo yum install -y $dep" >&2
	exit 1
}

echo -e "\nInfo: submit request to beaker ..."
baseUrl=http://pkgs.devel.redhat.com/cgit/tests/kernel/plain
submitlog=$(runtest  RHEL-7.5 "--cmd=wget $baseUrl/Library/base/tools/build_win_vm.sh -O /win.sh; bash /win.sh --winver=$winVer -- --vm-name win-$winVer --disk-size 60 answerfiles-cifs-nfs/*;" --hr-alias=vmhost)
echo "$submitlog"
job=$(egrep -o J:[0-9]+ <<<"$submitlog")
[[ -z $job ]] && {
	echo "Error: didn't get beaker job ID" >&2
	exit 1
}

echo -e "\nInfo: waiting beaker job getting machine ..."
while ! [[ "$jobstatus" = Install* ]]; do
	jobstatus=$(bkr job-results $job --prettyxml | sed -r -n '/<job .* status="([^"]*)".*/{s//\1/;p}')
	echo "Job status: $jobstatus"
	sleep 10
done
host=$(bkr job-results $job --prettyxml | sed -r -n '/.*system="([^"]*)".*/{s//\1/;p}')
[[ -z $host ]] && {
	echo "Error: didn't get beaker job host info" >&2
	exit 1
}

echo -e "\nInfo: waiting windows vm start install ..."
while ! nc -z $host 7788; do sleep 10; echo -n .; done


echo -e "\nvncviewer $host:7788 ..."
vncviewer $host:7788 -Encryption=PreferOff
