#!/bin/bash

{ #avoid crush self running

switchroot() {
	local P=$0 SH=; [[ -x $0 && $0 = /* ]] && command -v ${0##*/} &>/dev/null && P=${0##*/}; [[ ! -f $P || ! -x $P ]] && SH=$SHELL
	[[ $(id -u) != 0 ]] && {
		if [[ "${SHELL##*/}" = $P ]]; then
			echo -e "\E[1;31m{WARN} $P need root permission, please add sudo before $P\E[0m" >&2
			exit
		else
			echo -e "\E[1;4m{WARN} $P need root permission, switch to:\n  sudo $SH $P $@\E[0m" >&2
			exec sudo $SH $P "$@"
		fi
	}
}
switchroot "$@"

is_available_url() { curl --connect-timeout 8 -m 16 --output /dev/null -k --silent --head --fail "$1" &>/dev/null; }
is_rh_intranet() { host ipa.redhat.com &>/dev/null; }

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
