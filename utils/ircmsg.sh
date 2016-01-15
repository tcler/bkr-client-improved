#!/bin/bash
# A simple irc client based pure bash
# - used to send irc msg to notify some event
# - or your can use -i option to talk with others
# Author: yin-jianhong@163.com

##########################################################
# Config
SERVER="irc.devel.RH.com"
PORT=6667

NICK="testbot"
CHANNEL="#fs-fs"

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
	echo "    -i         work in interactive mode as a simple irc client"
	echo "    -d         open debug mode"
}
_at=`getopt -o hdC:c:in:s:p: -n 'ircmsg' -- "$@"`
eval set -- "$_at"
while true; do
	case "$1" in
	-h) Usage; shift 1; exit 0;;
	-d) DEBUG=1; shift 1;;
	-i) I=1; shift 1;;
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
exec 100<>/dev/tcp/${SERVER}/${PORT}
echo "NICK ${NICK}" >&100
echo "USER ${NICK} 8 * : ${NICK}" >&100
echo "JOIN ${CHANNEL}" >&100

while read line <&100; do
	test -n "$DEBUG" && echo $line
	read _serv _time _nick _tag _chan nlist <<< $line
	[[ $_tag = '=' ]] && {
		namelist=$nlist
		echo "[namelist] $namelist"
	}

	[[ $line =~ [^\ ]*\ JOIN\ $CHANNEL ]] && read head ignore <<<$line
	[[ $line =~ :End\ of\ /NAMES\ list. ]] && break
done

if [[ -n "$I" ]]; then
	#Fix me
	while read line <&100; do echo $line; done &
	while :; do
		echo -n "msg:> "
		read msg
		[[ $msg =~ ^\ *$ ]] && continue
		[[ "$msg" = quit ]] && {
			echo "$head QUIT" >&100
			kill $$; exit 0
		}
		echo "$head PRIVMSG ${chan:-$CHANNEL} " :$msg >&100
	done
else
	echo "$head PRIVMSG ${chan:-$CHANNEL} " :$msg >&100
	echo "QUIT" >&100
	exit $?
fi
