#!/bin/bash

P=$0; [[ $0 = /* ]] && P=${0##*/}
switchroot() {
	[[ $(id -u) != 0 ]] && {
		echo -e "{WARN} $P need root permission, switch to:\n  sudo $P $@" | GREP_COLORS='ms=1;30' grep --color=always . >&2
		exec sudo $P "$@"
	}
}
switchroot "$@"

_repon=bkr-client-improved
_confdir=/etc/$_repon
install_bkr_client_improved() {
	local url=https://github.com/tcler/$_repon
	local clonedir=$(mktemp -d)
	for ((i=0;i<8;i++)); do git clone $url $clonedir && break || sleep 2; done
	make -C $clonedir
	rm -rf $clonedir
}

tmpf=$(mktemp)
cleanup() { rm -rf $tmp; }
trap cleanup SIGINT SIGQUIT SIGTERM
wget -qO- http://api.github.com/repos/tcler/$_repon/commits/master -O $tmpf
if cmp $tmpf $_confdir/version 2>/dev/null; then
	echo "[Info] you are using the latest version"
else
	echo "[Info] found new version, installing ..."
	install_bkr_client_improved
fi
rm -f $tmpf
