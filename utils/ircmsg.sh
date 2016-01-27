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
CHANNEL="#fs-fs"

qe_assistant=/usr/local/bin/qe_assistant

[[ -f ~/.ircmsg.rc ]] && source ~/.ircmsg.rc
##########################################################
# Main
export LANG=C
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
}
_at=`getopt -o hdC:c:Iin:s:p: -n 'ircmsg' -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h) Usage; shift 1; exit 0;;
	-d) DEBUG=1; shift 1;;
	-i) I=1; shift 1;;
	-I) II=1; shift 1;;
	-C) CHANNEL=$2; shift 2;;
	-c) chan=$2; shift 2;;
	-n) NICK=$2; shift 2;;
	-s) SERVER=$2; shift 2;;
	-p) PORT=$2; shift 2;;
	--) shift; break;;
	esac
done

test -c /dev/tcp || {
	echo "[Warn] Can't find /dev/tcp, try 'sudo mknod /dev/tcp c 30 36'" >&2
	exit 1
}

msg="$*"
chan=${chan:-$CHANNEL}
echo "Connecting to ${SERVER}:${PORT} ..."
exec 100<>/dev/tcp/${SERVER}/${PORT}
[[ $? != 0 ]] && { exit 1; }

echo "NICK ${NICK}" >&100
echo "USER ${NICK} 8 * : ${NICK}" >&100
echo "JOIN ${CHANNEL}" >&100

while read line <&100; do
	test -n "$DEBUG" && echo $line
	read _serv _time _nick _tag _chan nlist <<< $line
	[[ $_tag = '=' ]] && {
		namelist=$nlist
		test -n "$DEBUG" && echo "[namelist] $namelist"
	}

	[[ $line =~ [^\ ]*\ JOIN\ $CHANNEL ]] && read head ignore <<<$line
	[[ $line =~ :End\ of\ /NAMES\ list. ]] && break
	[[ $line =~ .*No\ such\ channel|JOIN\ :Not\ enough\ parameters ]] && break
done

if [[ -z "$I" ]]; then
	echo "$head PRIVMSG ${chan:-$CHANNEL} " :$msg >&100
	echo "QUIT" >&100
	exit $?
fi

#Fix me
while read line <&100; do
	if [[ "$line" =~ PING ]]; then
		echo "$head ${line/PING/PONG}" >&100
	else
		echo -e "< $line"
		read _head _cmd _chan _msg <<<"$line"
		peernick=$(awk -F'[:!]' '{print $2}' <<<"${_head}")
		[[ "$_chan" = qe_assistant ]] && {
			_chan=$peernick
			_msg="qe_assistant $_msg"
		}
		if [[ -x "$qe_assistant" ]]; then
			$qe_assistant "$_msg" |
			while read l; do [[ -z "$l" ]] && continue; echo "$head PRIVMSG ${_chan} :$l"; done <$logf >&100
		fi
	fi

done &

[[ -z "$II" ]] && exit 0

help() {
	echo "/quit
/nick <new nick name>
/join <Channel|nick name>
/names [Channel]
/help"
}
while :; do
	echo -n "[$chan] "
	read msg
	[[ $msg =~ ^\ *$ ]] && continue
	case "$msg" in
	/quit)   echo "$head QUIT" >&100; kill $$; exit 0;;
	/nick*)  echo "$head ${msg/?nick/NICK}" >&100;;
	/join\ *)
		read ignore chan <<<"$msg"
		CHANNEL=$chan
		[[ ${chan:0:1} = '#' ]] && echo "JOIN ${CHANNEL}" >&100
		;;
	/names|/names\ *)
		read ignore _chan <<<"$msg"
		echo "NAMES ${_chan:-$chan}" >&100
		;;
	/raw\ *)
		read ignore rawdata <<<"$msg"
		echo "$rawdata" >&100
		;;
	/help)   help;;
	*)       echo "$head PRIVMSG ${chan} " :$msg >&100;;
	esac
done
