#!/bin/bash

Usage() {
	echo "Usage: $0 [options] <jobid>"
}

_at=`getopt -o h \
	--long help \
    -n "$0" -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h|--help)   Usage; shift 1; exit 0;;
	--) shift; break;;
	esac
done

if [[ $# < 1 ]]; then
	Usage >&2
	exit 1
fi

clean() { rm -f $jobf; }
trap "clean" SIGINT SIGTERM SIGHUP SIGQUIT

jobid=J:${1#J:}
jobf=(job-${jobid#J:}-clone-XXXXXXXX.xml)
bkr job-clone --prettyxml --dryrun $jobid &>$jobf
vim $jobf

echo "submit job ..."
sleep 1
bkr job-submit $jobf
clean
