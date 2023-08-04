#!/bin/bash

{ #avoid crush self running

P=$0; [[ $0 = /* ]] && P=${0##*/}
switchroot() {
	[[ $(id -u) != 0 ]] && {
		echo -e "{WARN} $P need root permission, switch to:\n  sudo $P $@" | GREP_COLORS='ms=1;30' grep --color=always . >&2
		exec sudo $P "$@"
	}
}
switchroot "$@"

is_available_url() { curl --connect-timeout 8 -m 16 --output /dev/null -k --silent --head --fail "$1" &>/dev/null; }
is_rh_intranet() { local iurl=http://download.devel.redhat.com; is_available_url $iurl; }

_repon=bkr-client-improved
_confdir=/etc/$_repon
install_bkr_client_improved() {
	local url=https://github.com/tcler/$_repon/archive/refs/heads/master.tar.gz
	local tmpdir=$(mktemp -d)
	curl -k -Ls $url | tar zxf - -C $tmpdir && make -C $tmpdir/${_repon}-master
	rm -rf $tmpdir
}

tmpf=$(mktemp)
cleanup() { rm -rf $tmp; }
trap cleanup SIGINT SIGQUIT SIGTERM

is_rh_intranet && export https_proxy=squid.redhat.com:8080
curl -Ls http://api.github.com/repos/tcler/$_repon/commits/master -o $tmpf
if cmp $tmpf $_confdir/version 2>/dev/null; then
	echo "[Info] you are using the latest version"
else
	echo "[Info] found new version, installing ..."
	install_bkr_client_improved
fi
rm -f $tmpf

exit
}
