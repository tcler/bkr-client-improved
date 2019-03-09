#! /bin/bash
#
#	Start/Stop Wub server

wubdir=/opt/wub
pushd $wubdir >/dev/null
port=8080

gethostname() {
	local host name domain hash coment

	HOST_FILE=/etc/redhat-ddns/hosts
	if [ -f "$HOST_FILE" ]; then
		read name domain hash comment < <(sed '/^\s*$/d; /^\s*#/d' $HOST_FILE)
		host=${name}.${domain}
	else
		read host _ <<< "$(hostname -A)"
	fi
	echo $host
}
wubstat() {
	local all=$1
	ps -U $LOGNAME -u $LOGNAME -o pid,user:16,cmd|grep -v grep|grep tclsh.*Wub.tcl &&
		echo -e "$(gethostname):$port/trms/?user=$LOGNAME"

	[[ -n "$all" ]] &&
		ps -a -o pid,user:16,cmd|grep -v grep|grep tclsh.*Wub.tcl
}

case "$1" in
  start)
	echo "Starting Wub server"
	ps -U $LOGNAME -u $LOGNAME -o pid,user:20,cmd|grep -v grep|grep tclsh.*Wub.tcl && exit 0
	nohup tclsh8.6 Wub.tcl site-trms.config 2>/dev/null &
	rm -f nohup.out
	wubstat
	;;
  stop)
	echo "Stoping Wub server"
	kill $(ps -U $LOGNAME -u $LOGNAME -o pid,user:20,cmd|grep -v grep|grep 'tclsh8.6.*Wub.tcl'|awk '{print $1}')
	sleep 1
	;;
  restart)
	echo "Retarting Wub server"
	kill $(ps -U $LOGNAME -u $LOGNAME -o pid,user:20,cmd|grep -v grep|grep 'tclsh8.6.*Wub.tcl'|awk '{print $1}')
	sleep 1
	nohup tclsh8.6 Wub.tcl site-trms.config 2>/dev/null &
	rm -f nohup.out
	wubstat
	;;
  status|stat)
	wubstat
	;;
  allstat|alls|all|al|a)
	wubstat all
	;;
  *)
	echo "Usage: $0 {start|stop|restart|stat|allstat}" >&2
	exit 1
	;;
esac

exit 0
