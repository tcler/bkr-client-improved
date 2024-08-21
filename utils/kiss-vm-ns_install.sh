#!/bin/bash
#

is_rh_intranet() { host ipa.redhat.com &>/dev/null; }
is_rh_intranet() { grep -q redhat.com /etc/resolv.conf; }
LOOKASIDE_BASE_URL=${LOOKASIDE:-http://download.devel.redhat.com/qa/rhts/lookaside}

if is_rh_intranet; then
	KISS_URL=${LOOKASIDE_BASE_URL}/kiss-vm-ns.tgz
	curl -k -Ls $KISS_URL | tar zxf -;
	make -C kiss-vm-ns; rm -rf kiss-vm-ns;
else
	KISS_URL=https://github.com/tcler/kiss-vm-ns/archive/refs/heads/master.tar.gz
	if command -v kiss-update.sh; then
		kiss-update.sh
	else
		rm -rf kiss-vm-ns-master;
		curl -k -Ls $KISS_URL | tar zxf -;
		make -C kiss-vm-ns-master; rm -rf kiss-vm-ns-master;
	fi
fi
