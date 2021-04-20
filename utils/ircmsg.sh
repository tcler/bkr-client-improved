#!/bin/bash
# A simple irc client based pure bash
# - used to send irc msg to notify some event
# - or your can use -I option to talk with others
# Author: yin-jianhong@163.com

##########################################################
# Config
P=$(readlink -f $0)
PROXY_SERVER="host.that.are.running.ircproxy"
PROXY_PORT=6667
ProxySession=
UserPasswd=

NICK="testbot"
#CHANNEL="#fs-fs"
CHANNEL=

qe_assistantx=/usr/local/bin/qe_assistant
configdir=~/.config/ircmsg
recorddir=$configdir/record/

if [[ -f ~/.ircmsg/ircmsg.rc ]]; then
	mkdir -p ~/.config
	mv ~/.ircmsg ~/.config/ircmsg
fi
[[ -f ~/.config/ircmsg/ircmsg.rc ]] && source ~/.config/ircmsg/ircmsg.rc
##########################################################
# Main
export LANG=C
Interactive=no
msg=
namelist=
 
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
	echo "    -I         work in interactive mode as a simple irc client, not finish"
	echo "    -i         run as a deamon robot"
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
	-I) Interactive=yes; shift 1;;
	-i) Interactive=deamon; shift 1;;
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

while read line; do
	[ -z "$line" ] && continue
	echo "$Head PRIVMSG ${Chan} :$line" >&100
done <<<"$msg"

if [[ $Interactive = no ]]; then
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
elif [[ $Interactive = deamon ]]; then
	if [[ -z "$TMUX" ]]; then
		echo "have to run $P with -i option in tmux:"
		echo "    tmux new -s ircmsg0 -d \"$P ${_at[@]}\""
		exit 0
	fi

	bgnick=$NICK
	mkdir -p $recorddir

	while read line <&100; do
		line=${line/$'\r'/}
		if [[ "$line" =~ PING ]]; then
			echo "$Head ${line/PING/PONG}" >&100
		else
			chanfile=$Chan
			read _head _cmd _chan _msg <<<"$line"
			[[ $_cmd = MODE || $_cmd =~ [0-9]+ ]] && {
				echo -e "${_head%\!*}! ${_cmd} ${_chan} $_msg" >>$recorddir/$chanfile
				continue
			}
			[[ $_cmd = PRIVMSG ]] && {
				peernick=$(awk -F'[:!]' '{print $2}' <<<"${_head}")
				chanfile=${_chan}
				[[ ${_chan:0:1} = "#" ]] || chanfile=$peernick
			}
			echo -e "${_head%\!*}! ${_cmd} ${_chan} $_msg" >>$recorddir/$chanfile
			[[ "$_chan" = $bgnick ]] && {
				_chan=$peernick
				_msg="$bgnick $_msg"
			}
			if [[ -x "$qe_assistantx" ]]; then
				$qe_assistantx "$_msg  from:${_chan}" | tee -a $recorddir/$chanfile |
				while read line; do [[ -z "$line" ]] && continue; echo "$Head PRIVMSG ${_chan} :$line"; done >&100
			fi
		fi
	done

#fixme not finish
else
	if ! grep ^ircmsg0: < <(tmux ls); then
		echo "tmux session ircmsg0 is required, please try run bellow cmd line first:"
		echo "    tmux new -s ircmsg0 -d \"$P ${_at[*]/-I/-i}\""
		exit 0
	fi

	trap "sigproc" SIGINT SIGTERM SIGHUP SIGQUIT
	sigproc() {
		kill $pid 2>/dev/null
		exit
	}

	help() {
		echo "
	/quit;
	/part;
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
		dialog --backtitle "irc $NICK($chan); proxy.user(${UserPasswd%:*})" --no-shadow \
			--begin 2 0 --title "$NICK($chan)" --tailboxbg $recorddir/$chan 27 120 --and-widget \
			--begin 30 0 --title "$NICK($chan)" --inputbox "" 5 120  2>$configdir/msg.txt
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
		/exit|/quit)
			kill $pid $$; exit 0;;
		/part)
			echo -e "$Head PART ${chan} I-am-leaving" >&100
			echo -e "$Head /PART ${chan} leaving" >&100
			kill $pid $$
			exit 0
			;;
		*)	echo "${Head} PRIVMSG ${chan} :$msg" >&100
			echo "${Head} PRIVMSG ${chan} :$msg" >>$recorddir/$chan
			;;
		esac
	done
fi
