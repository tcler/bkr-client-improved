#!/bin/bash

which gcc || yum install -y gcc
pkg=tdom-0.9.6-src.tgz
curl -o $pkg -L http://tdom.org/downloads/$pkg
[ -f "$pkg" ] || {
	echo "$pkg not exist!" >&2
	exit 1
}

compileDir=${pkg%-src.tgz}
mkdir -p $compileDir
tar -C $compileDir -zxf "$pkg" --strip-components=1 '*/*'
pushd $compileDir/unix
	../configure --libdir=/usr/local/lib --with-tcl=/usr/lib64 &&
	make && make install
popd
rm -rf ${pkg} $compileDir
