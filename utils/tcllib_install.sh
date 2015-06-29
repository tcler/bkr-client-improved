#!/bin/bash

which gcc || yum install -y gcc
pkg=Tcllib-1.16.tar.bz2

#wget http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved/$pkg
wget -O $pkg http://sourceforge.net/projects/tcllib/files/tcllib/1.16/tcllib-1.16.tar.bz2/download ||
wget -O $pkg https://qa.debian.org/watch/sf.php/tcllib/tcllib-1.16.tar.bz2
[ -f "$pkg" ] || {
	echo "$pkg not exist!" >&2
	exit 1
}

tar jxf $pkg
pushd ${pkg%.tar.*}
	./configure --libdir=/usr/lib && make install
popd
rm -rf ${pkg} Tcllib-1.16
