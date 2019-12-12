#!/bin/bash

which nc &>/dev/null || dep=nmap-ncat
[[ -n "$dep" ]] && {
	echo -e "{Info} install dependences ..."
	sudo yum install -y $dep >&2
}

Usage() {
	echo "Usage: $0 [-h] [-d] [-w|-wait] <host:port>"
}

port_available() {
	nc $1 $2 </dev/null &>/dev/null
}

# parse options
AT=()
for arg; do
	case "$arg" in
	-h)       Usage; exit;;
	-d)       DEBUG=yes;;
	-w|-wait) WAIT=yes;;
	-*)       echo "{WARN} unkown option '${arg}'" >&2;;
	*)        AT+=($arg);;
	esac
done

[[ -z "${AT}" ]] && {
	Usage >&2
	exit 1
}

if [[ "$AT" = [* ]]; then
	IFS=']' read addr port <<<"${AT}"
	addr="${addr#[}"
	port="${port#:}"
else
	IFS=: read addr port <<<"${AT}"
fi

[[ "$DEBUG" = yes ]] && echo "{info} $addr $port"
if [[ "$WAIT" = yes ]]; then
	until port_available $addr $port; do sleep 1; done
else
	port_available $addr $port
fi
