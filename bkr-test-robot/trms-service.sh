#! /bin/bash
#
#	Start/Stop Wub/TRMS server

wubdir=/opt/wub2
pushd $wubdir >/dev/null
conff=site-trms.config
port=$(sed -n -e '/^ *Listener {/,/}/{/^ *#/d;p}' $conff | awk '/-port/{print $2}')

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
trmsstat() {
	local all=$1
	local ip=$(getDefaultIp|tail -1)
	ps -U root -u root -o pid,user:16,cmd|grep -v grep|grep tclsh.*Wub.tcl && {
		if [[ $LOGNAME != root ]]; then
			echo -e "url: $ip:$port/trms/?user=$LOGNAME"
		else
			echo -e "url: $ip:$port"
		fi
	}

	[[ -n "$all" ]] && {
		echo -e "\n[All instances(old version)]"
		ps -a -o pid,user:16,cmd|grep -v grep|grep tclsh.*Wub.tcl
	}
}
start() {
	echo "Starting Wub/TRMS server"
	ss -ltunp | grep -q :$port && {
		echo -e "[Warn] port($port) has been used\n" >&2
		trmsstat allstat
		return 1
	}
	ps -U $LOGNAME -u $LOGNAME -o pid,user:20,cmd|grep -v grep|grep tclsh.*Wub.tcl && exit 0
	nohup tclsh8.6 Wub.tcl site-trms.config 2>/dev/null &
	rm -f nohup.out

	local ip=$(getDefaultIp|tail -1)
	echo -n "Waiting service(${ip}:${port}) is available"
	while ! nc $ip $port </dev/null &>/dev/null; do sleep 5; echo -n .; done
	echo
	trmsstat
}
stop() {
	echo "Stoping Wub/TRMS server"
	kill $(ps -U $LOGNAME -u $LOGNAME -o pid,user:20,cmd|grep -v grep|grep 'tclsh8.6.*Wub.tcl'|awk '{print $1}')
	sleep 1
}

case "$1" in
  start|stop|restart)
	[ $(id -u) != 0 ] && {
		echo "[Warn] Wub/TRMS service need root permission to access users test data, please try:" >&2
		echo " sudo $0 $@" >&2
		exit 1
	}
	;;
esac

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
	trmsstat;;
  allstat|alls|all|al|a)
	trmsstat all;;
  *)
	echo "Usage: $0 {start|stop|restart|stat|allstat}" >&2
	exit 1
	;;
esac

exit 0
