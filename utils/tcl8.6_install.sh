#!/bin/bash

test `id -u` = 0 || {
	exec sudo $0 "$@"
}

which gcc || yum install -y gcc
pkg=tcl8.6.10-src.tar.gz
wget https://prdownloads.sourceforge.net/tcl/$pkg
[ -f "$pkg" ] || {
	echo "$pkg not exist!" >&2
	exit 1
}

tar zxf $pkg
pushd ${pkg%%-*}/unix
	./configure --prefix=/usr && make && make install
	ln -sf  /usr/bin/tclsh8.6  /usr/bin/tclsh
	ln -sf  /bin/tclsh8.6  /bin/tclsh
popd
rm -rf ${pkg} ${pkg%%-*}
