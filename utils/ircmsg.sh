#!/bin/bash
# A simple irc client based pure bash
# - used to send irc msg to notify some event
# - or your can use -I option to talk with others
# Author: yin-jianhong@163.com

##########################################################
# Config
SERVER="irc.devel.RH.com"
PORT=6667

NICK="testbot"
#CHANNEL="#fs-fs"
CHANNEL=

qe_assistant=/usr/local/bin/qe_assistant

[[ -f ~/.ircmsg/ircmsg.rc ]] && source ~/.ircmsg/ircmsg.rc
##########################################################
# Main
export LANG=C
I=0
msg=
namelist=
fix=$RANDOM
 
P=${0##*/}
#-------------------------------------------------------------------------------
Usage() {
	echo "Usage: $P [-hdinc] [-C channel] [-s serv -p port] msg"
	echo "  Options:"
	echo "    -n <nick>  used \$nick as nick name to JOIN channel"
	echo "    -c <nick>  used to send private msg to \$nick"
	echo "    -i         run as a deamon robot"
	echo "    -I         work in interactive mode as a simple irc client"
	echo "    -d         open debug mode"
	echo "    -q         quit after send message"
	echo "    -P <session:addr>	proxy session name"
	echo "    -L <user:passwd>	proxy login user and passwd"
}
_at=`getopt -o hdC:c:Iin:s:p:qP:L: --long create-session \
-n 'ircmsg' -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h) Usage; shift 1; exit 0;;
	-d) DEBUG=1; shift 1;;
	-i) I=1; shift 1;;
	-I) I=2; shift 1;;
	-C) CHANNEL=$2; shift 2;;
	-c) Chan=$2; shift 2;;
	-n) NICK=$2; shift 2;;
	-s) SERVER=$2; shift 2;;
	-p) PORT=$2; shift 2;;
	-q) QUIT=1; shift 1;;
	-P) ProxySession=$2; shift 2;;
	-L) UserPasswd=$2; shift 2;;
	--create-session) CreateSession=1; shift 1;;
	--) shift; break;;
	esac
done

test -c /dev/tcp || {
	echo "[Warn] Can't find /dev/tcp, try 'sudo mknod /dev/tcp c 30 36'" >&2
	exit 1
}

msg="$*"
Chan=${Chan:-$CHANNEL}
Chan=${Chan:-NULL}
echo "Connecting to ${SERVER}:${PORT} ..."
exec 100<>/dev/tcp/${SERVER}/${PORT}
[[ $? != 0 ]] && { exit 1; }

echo "NICK ${NICK}" >&100
echo "USER ${NICK} 8 * : ${NICK}" >&100

test -n "$ProxySession" && {
	read session addr <<<"${ProxySession/:/ }"
	while read line <&100; do
		test -n "$DEBUG" && echo $line
		[[ $line =~ NOTICE.AUTH.:To.connect ]] && break
	done

	echo "PRIVMSG root :${UserPasswd/:/ }" >&100
	read line <&100 && echo "proxy: $line"

	test -n $CreateSession && echo "PRIVMSG root :create ${session} ${addr}" >&100
	echo "PRIVMSG root :connect ${session}" >&100
}

test -n "${CHANNEL}" && echo "JOIN ${CHANNEL}" >&100
while read line <&100; do
	test -n "$DEBUG" && echo $line
	read _serv _time _nick _tag _chan nlist <<< $line
	[[ $_tag = '=' ]] && {
		namelist=$nlist
		test -n "$DEBUG" && echo "[namelist] $namelist"
	}

	[[ $line =~ [^\ ]*\ JOIN\ $CHANNEL ]] && read Head ignore <<<$line
	[[ $line =~ :End\ of\ /NAMES\ list. ]] && break
	[[ $line =~ .*No\ such\ channel|JOIN\ :Not\ enough\ parameters ]] && break
done

if [[ $I = 0 ]]; then
	while read l; do
		[ -z "$l" ] && continue
		echo "$Head PRIVMSG ${Chan} :$l" >&100
	done <<<"$msg"

	test -n "$QUIT" && echo "$Head QUIT" >&100
	test -z "$ProxySession" && echo "$Head QUIT" >&100
	exit $?
fi

configdir=~/.ircmsg
recorddir=$configdir/record/
mkdir -p $recorddir

#Fix me
while read line <&100; do
	line=${line/$'\r'/}
	if [[ "$line" =~ PING ]]; then
		echo "$Head ${line/PING/PONG}" >&100
	else
		chanfile=$Chan
		read _head _cmd _chan _msg <<<"$line"
		[[ $_cmd = MODE || $_cmd =~ [0-9]+ ]] && {
			echo -e "${_head%!*}! ${_cmd} ${_chan} $_msg" >>$recorddir/$chanfile
			continue
		}
		[[ $_cmd = PRIVMSG ]] && {
			peernick=$(awk -F'[:!]' '{print $2}' <<<"${_head}")
			chanfile=${_chan}
			[[ ${_chan:0:1} = "#" ]] || chanfile=$peernick
		}
		echo -e "${_head%\!*}! ${_cmd} ${_chan} $_msg" >>$recorddir/$chanfile
		[[ "$_chan" = qe_assistant ]] && {
			_chan=$peernick
			_msg="qe_assistant $_msg"
		}
		if [[ -x "$qe_assistant" ]]; then
			$qe_assistant "$_msg" |
			while read l; do [[ -z "$l" ]] && continue; echo "$Head PRIVMSG ${_chan} :$l"; done >&100
		fi
	fi

done &
pid=$!
echo $pid

[[ $I -le 1 ]] && exit 0

trap "sigproc" SIGINT SIGTERM SIGHUP SIGQUIT
sigproc() {
	kill $pid
	exit
}

help() {
	echo "/quit;
/nick <new nick name>;
/join <Channel|nick name>;
/names [Channel];
/help"
}

export NCURSES_NO_UTF8_ACS=1
curchan=$configdir/curchan
echo -n $Chan >$curchan
while :; do
	chan=$(< $curchan)
	touch $recorddir/$chan
	dialog --backtitle "irc $_chan" --no-shadow \
		--begin 2 0 --title "irc $chan" --tailboxbg $recorddir/$chan 27 120 --and-widget \
		--begin 30 0 --title "irc $chan" --inputbox "" 5 120  2>$configdir/msg.txt
	retval=$?
	msg=$(< $configdir/msg.txt)

	[[ $msg =~ ^\ *$ ]] && continue
	case "$msg" in
	/nick*)
		read ignore _nick
		[ -n $_nick ] && NICK=$_nick
		echo "$Head NICK ${NICK}" >&100
		;;
	/join\ *)
		read ignore _chan <<<"$msg"
		Chan=$_chan
		[[ ${Chan:0:1} = '#' ]] && echo "JOIN ${Chan}" >&100
		echo -n $Chan >$curchan
		;;
	/names|/names\ *)
		read ignore _chan <<<"$msg"
		echo "NAMES ${_chan:-$chan}" >&100
		;;
	/raw\ *)
		read ignore rawdata <<<"$msg"
		echo "$rawdata" >&100
		;;
	/msg\ *)
		read ignore tonick _msg <<<"$msg"
		echo "PRIVMSG $tonick :$_msg" >&100
		echo "PRIVMSG $tonick :$_msg" >>$recorddir/$chan
		;;
	/help)
		help >>$recorddir/$chan;;
	/disconnect)
		kill $pid $$; exit 0;;
	/quit)	echo "$Head QUIT" >&100; kill $pid $$; exit 0;;
	*)	echo "${Head} PRIVMSG ${chan} :$msg" >&100
		echo "${Head} PRIVMSG ${chan} :$msg" >>$recorddir/$chan
		;;
	esac
done
