#!/bin/bash

export LANG=C
P=${0##*/}
#-------------------------------------------------------------------------------
Usage() {
	echo "Usage: $P [single]"
}
_at=`getopt -a -o h \
	--long help \
    -a -n "$P" -- "$@"`
eval set -- "$_at"

while true; do
	case "$1" in
	-h|--help)    Usage; shift 1; exit 0;;
	--)           shift; break;;
	esac
done

HostDistro=${HostDistro:-Fedora-32}
KissVMUrl=https://github.com/tcler/kiss-vm-ns
ImageUrl=ftp://fs-qe.usersys.redhat.com/pub/Netapp-Simulator/vsim-netapp-DOT9.7-cm_nodar.ova
ImageUrl=http://download.devel.redhat.com/qa/rhts/lookaside/Netapp-Simulator/vsim-netapp-DOT9.7-cm_nodar.ova
script=ontap-simulator-9.7-two-node.sh
[[ -n "$1" ]] && script=ontap-simulator-9.7-single-node.sh
submitlog=$(runtest --random ${HostDistro} '--cmd=git clone '"$KissVMUrl"'; sudo make -C kiss-vm-ns; sudo vm --prepare; wget '"$ImageUrl"'; tar vxf vsim-netapp-DOT9.7-cm_nodar.ova; for i in {1..4}; do qemu-img convert -f vmdk -O qcow2 vsim-NetAppDOT-simulate-disk${i}.vmdk vsim-NetAppDOT-simulate-disk${i}.qcow2; done; git clone https://github.com/tcler/ontap-simulator-in-kvm; bash ontap-simulator-in-kvm/'$script -hr=memory\>=16384 --hr=kv-DISKSPACE\>=500000)

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
	[[ "$jobstatus" = Aborted || "$jobstatus" = Can* ]] && {
		echo "Error: beaker job Aborted or Cancelled, please check distro and try again" >&2
		exit 1
	}
	sleep 10
done
host=$(bkr job-results $job --prettyxml | sed -r -n '/.*system="([^"]*)".*/{s//\1/;p}')
[[ -z $host ]] && {
	echo "Error: didn't get beaker job host info" >&2
	exit 1
}

echo -e "\nInfo: waiting host OS install done ..."
#while ! nc -z $host 22; do sleep 10; echo -n .; done
while ! nc $host 22 </dev/null &>/dev/null; do sleep 10; echo -n .; done

echo -e "\nInfo: waiting ontap simulator install done ..."
while ! grep -q /distribution/command.*status=.Completed < <(bkr job-results $job --prettyxml); do sleep 10; echo -n .; done
grep /distribution/command.*status=.Completed < <(bkr job-results $job --prettyxml)

echo -e "\nInfo: getting ontap lif's info ..."
task=$(bkr job-results $job --prettyxml | sed -rn '/name=.\/distribution\/command/{s;^.*id="([0-9]+)".*$;\1;; p}')
logurl=$(bkr job-logs $job|grep /$task/.*taskout.log)
curl -s -L $logurl| tac | sed -nr '/^[ \t]+lif/ {:loop /\nfsqe-[s2]nc1/!{N; b loop}; p;q}'|tac
