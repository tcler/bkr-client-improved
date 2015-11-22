#!/bin/bash

which gcc || yum install -y gcc
pkg=tDOM-0.8.3.tgz
pkg2=tdom_0_8_3_postrelease.tar.gz

#wget http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved/$pkg
wget https://github.com/tDOM/tdom/archive/$pkg2
mv $pkg2 $pkg
[ -f "$pkg" ] || {
	echo "$pkg not exist!" >&2
	exit 1
}

compileDir=tDOM-0.8.3
mkdir -p $compileDir
tar -C $compileDir -zxf "$pkg" --strip-components=1 '*/*'
pushd $compileDir/unix
	../configure --libdir=/usr/local/lib --with-tcl=/usr/lib64 &&
	make && make install
popd
rm -rf ${pkg} $compileDir
