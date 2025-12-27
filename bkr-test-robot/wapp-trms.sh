#!/bin/bash

shlib=/usr/lib/bash/libtest.sh; [[ -r $shlib ]] && source $shlib
needroot() { [[ $EUID != 0 ]] && { echo -e "\E[1;4m{WARN} $0 need run as root.\E[0m"; exit 1; }; }
[[ function = "$(type -t switchroot)" ]] || switchroot() { needroot; }
switchroot "$@"

sname=wapp-trms
logf=/tmp/wapp-trms.log
wappf=/usr/local/libexec/wapp-trms.tcl
port=9090

start() {
	semanage port -a -t http_port_t -p tcp $port
	if tmux has-session -t $sname 2>/dev/null; then
		echo "{info} wapp-trms has been started"
	else
		run -as=root -tmux=$sname -logf=$logf tclsh $wappf -server $port -Dallow-multi-qp=yes
		while [[ ! -f $logf ]]; do sleep 1; done
	fi
	[[ -f $logf ]] && cat $logf
}
stop() {
	tmux kill-session -t $sname
}
_stat() {
	if tmux has-session -t $sname 2>/dev/null; then
		[[ -f $logf ]] && cat $logf
	else
		echo "{info} wapp-trms is not started"
	fi
}

case "$1" in
  start)
	start;;
  stop)
	stop;;
  restart)
	stop
	start
	;;
  status|stat)
	_stat;;
  *)
	echo "Usage: $0 {start|stop|restart|stat}" >&2
	exit 1
	;;
esac

