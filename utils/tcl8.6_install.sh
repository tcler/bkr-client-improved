#!/bin/bash

test `id -u` = 0 || {
	exec sudo $0 "$@"
}

which gcc || yum install -y gcc
pkg=tcl8.6.9-src.tar.gz
wget https://prdownloads.sourceforge.net/tcl/tcl8.6.9-src.tar.gz
[ -f "$pkg" ] || {
	echo "$pkg not exist!" >&2
	exit 1
}

tar zxf $pkg
pushd tcl8.6.9/unix
	./configure --prefix=/usr && make && make install
	ln -sf  /usr/bin/tclsh8.6  /usr/bin/tclsh
	ln -sf  /bin/tclsh8.6  /bin/tclsh
popd
rm -rf ${pkg} tcl8.6.9
