#!/bin/sh
# to build the bkr-client-improved rpm and update.
# autor: jiyin@redhat.com

OPWD=$PWD
cd $(dirname ${0})
fspec=$1
[ -z "$fspec" ] && fspec=$(ls *.spec|head -n1)
[ ! -r $fspec ] && {
	echo "[Err] Can't find the spec file" >&2
	exit 1
}
pkgName=$(awk -F'[: ]+' '$1=="Name"{print $2}' $fspec)
version=$(awk -F'[: ]+' '$1=="Version"{print $2}' $fspec)

genTarFile() {
	local ftar=${1}
	local dirList=${2}

	pushd sysroot >/dev/null
	tar zcf $ftar ${dirList//,/ }
	mv $ftar ../.; cd ..
	popd >/dev/null
}

pkgname=bkr-client-improved
mkdir -p sysroot/usr/local/{src,lib,bin,sbin} sysroot/etc/$pkgname \
	sysroot/usr/share/$pkgname
cp -arf lib/*  sysroot/usr/local/lib/.
cp -af share/* sysroot/usr/share/$pkgname/.
cp -af bkr*/* utils/* sysroot/usr/local/bin/.
cp -af cron_task/* sysroot/usr/local/sbin/.
rm -rf sysroot/usr/local/bin/www{,2}
cp -af conf/* sysroot/etc/$pkgname/.
FTAR=${pkgName}-$version.tar.gz
genTarFile ${FTAR} usr,etc,var,opt
[ $? = 0 ] && {
	mkdir -p ~/rpmbuild/{SPECS,SOURCES}
	find ~/rpmbuild/RPMS/ -name "${pkgName}-*.rpm"|xargs rm -f
	cp ${FTAR} ~/rpmbuild/SOURCES/.
	rpmbuild -bb $pkgname.spec
}

rm -rf sysroot
cp ~/rpmbuild/RPMS/*/${pkgName}*.rpm $OPWD/.
rm ${FTAR}

