#!/bin/bash

test $(id -u) = 0 || { echo "[Warn] need root permission" >&2; exit 1; }

install_bkr_client_improved() {
	local url=https://github.com/tcler/bkr-client-improved
	local clonedir=$(mktemp -d)
	git clone $url $clonedir
	make -C $clonedir
	rm -rf $clonedir
}

_confdir=/etc/bkr-client-improved
tmpf=$(mktemp)
wget -qO- http://api.github.com/repos/tcler/kiss-vm-ns/commits/master -O $tmpf
if cmp $tmpf $_confdir/version 2>/dev/null; then
	echo "[Info] you are using the latest version"
else
	echo "[Info] found new version, installing ..."
	install_bkr_client_improved
fi
rm -f $tmpf
