#! /bin/sh
#
#	Start/Stop Wub server

wubdir=/opt/wub
pushd $wubdir >/dev/null

case "$1" in
  start)
	echo "Starting Wub server"
	ps axf|grep -v grep|grep tclsh.*Wub/Application.tcl && exit 0
	nohup tclsh8.6 Wub/Application.tcl 2>/dev/null &
	rm -f nohup.out
	ps axf|grep -v grep|grep tclsh.*Wub/Application.tcl
	;;
  stop)
	echo "Stoping Wub server"
	kill $(ps axf|grep -v grep|grep 'tclsh8.6.*Wub/Application.tcl'|awk '{print $1}')
	sleep 1
	;;
  restart)
	echo "Retarting Wub server"
	kill $(ps axf|grep -v grep|grep 'tclsh8.6.*Wub/Application.tcl'|awk '{print $1}')
	sleep 1
	nohup tclsh8.6 Wub/Application.tcl 2>/dev/null &
	rm -f nohup.out
	ps axf|grep -v grep|grep tclsh.*Wub/Application.tcl
	;;
  *)
	echo "Usage: $0 {start|stop|restart}" >&2
	exit 1
	;;
esac

exit 0
