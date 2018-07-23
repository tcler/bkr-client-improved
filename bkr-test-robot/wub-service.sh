#! /bin/bash
#
#	Start/Stop Wub server

wubdir=/opt/wub
port=$(($(id -u) + 7080))
confdir=~/.wub
pushd $wubdir >/dev/null

mkdir -p $confdir
sed "/-port .*HTTP listener/s/8080/$port/" site.config >$confdir/site.config

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
	ps -U $LOGNAME -u $LOGNAME -o pid,user:16,cmd|grep -v grep|grep tclsh.*Wub/Application.tcl &&
		echo -e "$(gethostname):$port"
}

case "$1" in
  start)
	echo "Starting Wub server"
	ps -U $LOGNAME -u $LOGNAME -o pid,user:20,cmd|grep -v grep|grep tclsh.*Wub/Application.tcl && exit 0
	nohup tclsh8.6 Wub/Application.tcl 2>/dev/null &
	rm -f nohup.out
	wubstat
	;;
  stop)
	echo "Stoping Wub server"
	kill $(ps -U $LOGNAME -u $LOGNAME -o pid,user:20,cmd|grep -v grep|grep 'tclsh8.6.*Wub/Application.tcl'|awk '{print $1}')
	sleep 1
	;;
  restart)
	echo "Retarting Wub server"
	kill $(ps -U $LOGNAME -u $LOGNAME -o pid,user:20,cmd|grep -v grep|grep 'tclsh8.6.*Wub/Application.tcl'|awk '{print $1}')
	sleep 1
	nohup tclsh8.6 Wub/Application.tcl 2>/dev/null &
	rm -f nohup.out
	wubstat
	;;
  stat|status)
	wubstat
	;;
  *)
	echo "Usage: $0 {start|stop|restart|stat[us]}" >&2
	exit 1
	;;
esac

exit 0
