#!/bin/bash
#author: jiyin@redhat.com

dir=.kkk$$
pkglist=`rpm -q --qf "%{NAME}\n" "$@" | grep -v 'package .* is not installed' | sort -u | xargs`
[ -z "$pkglist" ] && {
	echo "packages not exist."
	exit
}
name=${pkglist// /__}
#echo "name === $name"

flist=`rpm -ql $pkglist`;
[ -z "$flist" ] && exit 

echo "copy file ..."
mkdir $dir;
for f in $flist; do
	mkdir -p $dir$(dirname $f);
	[ -d $f ] && continue;
	[ -f $f ] && \cp -af $f $dir$f || echo "{WARN} $f not exist" >&2;
done;

echo "create package ..."
pushd $dir >/dev/null;
	tar zcf $name.tar.gz *;
popd >/dev/null;
mv $dir/$name.tar.gz .;

rm -rf $dir;

