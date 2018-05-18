#!/bin/bash

test `id -u` = 0 || {
	exec sudo $0 "$@"
}

which gcc || yum install -y gcc
pkg=tcl8.6.4-src.tar.gz
#wget http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved/$pkg
wget http://prdownloads.sourceforge.net/tcl/tcl8.6.4-src.tar.gz
[ -f "$pkg" ] || {
	echo "$pkg not exist!" >&2
	exit 1
}

tar zxf $pkg
pushd tcl8.6.4/unix
	./configure --prefix=/usr && make && make install
	which tclsh >/dev/null ||
		ln -s  /usr/bin/tclsh8.6  /usr/bin/tclsh
popd
rm -rf ${pkg} tcl8.6.4
