#!/bin/bash
# A simple irc client based pure bash
# - used to send irc msg to notify some event
# - or your can use -I option to talk with others
# Author: yin-jianhong@163.com

##########################################################
# Config
PROXY_SERVER="host.that.are.running.ircproxy"
PROXY_PORT=6667
ProxySession=
UserPasswd=

NICK="testbot"
#CHANNEL="#fs-fs"
CHANNEL=

qe_assistant=/usr/local/bin/qe_assistant

if [[ -f ~/.ircmsg/ircmsg.rc ]]; then
	mkdir -p ~/.config
	mv ~/.ircmsg ~/.config/ircmsg
fi
[[ -f ~/.config/ircmsg/ircmsg.rc ]] && source ~/.config/ircmsg/ircmsg.rc
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
	echo "Usage: $P [-hqdiI] [-s serv -p port -S session] {-n <nick> [-C channel [-c <nick>]]} msg"
	echo "  Options:"
	echo "    -n <nick>  used \$nick as nick name to JOIN channel"
	echo "    -C <chan>  used to join into \$chan"
	echo "    -c <nick>  used to send private msg to \$nick"
	echo "    -s <proxyserv> proxy server addr, or set 'PROXY_SERVER=' in ~/.config/ircmsg/ircmsg.rc"
	echo "    -p <proxyserv> proxy server port, or set 'PROXY_PORT=' in ~/.config/ircmsg/ircmsg.rc"
	echo "    -S <name:irc_serv_addr> proxy session, or set 'ProxySession=' in ~/.config/ircmsg/ircmsg.rc"
	echo "    -U <user:passwd> proxy login user and passwd, or set 'UserPasswd=' in ~/.config/ircmsg/ircmsg.rc"
	echo "    -q         quit or quit after send message"
	echo "    -d         open debug mode"
	echo "    -i         run as a deamon robot"
	echo "    -I         work in interactive mode as a simple irc client"
	echo
	echo "Example:"
	echo "  $P [-s serv -p port -S session] -n testbot -C #chan msg  #channel msg"
	echo "  $P [-s serv -p port -S session] -n testbot -C #chan -c mike msg  #private msg"
	echo "  $P [-s serv -p port -S session] -n testbot -C #chan -q  #quit from #chan"
}
_at=`getopt -o hdqn:C:c:s:p:S:P:U:L:iI --long create-session \
-n 'ircmsg' -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h) Usage; shift 1; exit 0;;
	-d) DEBUG=1; shift 1;;
	-n) NICK=$2; shift 2;;
	-C) CHANNEL=$2; shift 2;;
	-c) Chan=$2; shift 2;;
	-s) PROXY_SERVER=$2; shift 2;;
	-p) PROXY_PORT=$2; shift 2;;
	-S|-P) ProxySession=$2; shift 2;;
	-U|-L) UserPasswd=$2; shift 2;;
	--create-session) CreateSession=1; shift 1;;
	-q) QUIT=1; shift 1;;
	-i) I=1; shift 1;;
	-I) I=2; shift 1;;
	--) shift; break;;
	esac
done

test -c /dev/tcp || {
	if test $(id -u) = 0; then
		mknod /dev/tcp c 30 36
	else
		echo "[Warn] Can't find /dev/tcp, try 'sudo mknod /dev/tcp c 30 36'" >&2
		exit 1
	fi
}

msg="$*"
Chan=${Chan:-$CHANNEL}
Chan=${Chan:-NULL}
echo "Connecting to ${PROXY_SERVER}:${PROXY_PORT} ..."
exec 100<>/dev/tcp/${PROXY_SERVER}/${PROXY_PORT}
[[ $? != 0 ]] && { exit 1; }

echo "NICK ${NICK}" >&100
echo "USER ${NICK} 8 * : ${NICK}" >&100

test -n "$ProxySession" && {
	read session ircserv <<<"${ProxySession/:/ }"
	while read line <&100; do
		test -n "$DEBUG" && echo $line
		[[ $line =~ NOTICE.AUTH.:To.connect ]] && break
	done

	echo "PRIVMSG root :${UserPasswd/:/ }" >&100
	read line <&100 && echo "proxy: $line"

	test -n $CreateSession && echo "PRIVMSG root :create ${session} ${ircserv}" >&100
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
	while read line; do
		[ -z "$line" ] && continue
		echo "$Head PRIVMSG ${Chan} :$line" >&100
	done <<<"$msg"

	if test -n "$QUIT"; then
		if test -n "${CHANNEL}"; then
			#leaving from chan
			echo -e "$Head PART ${Chan} I-am-leaving" >&100
			echo -e "$Head /PART ${Chan} leaving" >&100
		else
			echo "$Head QUIT" >&100
		fi
	fi
	test -z "$ProxySession" && echo "$Head QUIT" >&100
	exit $?
fi

configdir=~/.config/ircmsg
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
			while read line; do [[ -z "$line" ]] && continue; echo "$Head PRIVMSG ${_chan} :$line"; done >&100
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
