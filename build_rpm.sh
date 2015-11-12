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

mkdir -p sysroot/usr/local/{src,lib,bin} sysroot/etc/bkr-client-improved
cp -arf lib/*  sysroot/usr/local/lib/.
cp -af bkr*/* utils/* cron_task/* sysroot/usr/local/bin/.
cp -af conf/* sysroot/etc/bkr-client-improved/.
FTAR=${pkgName}-$version.tar.gz
genTarFile ${FTAR} usr,etc,var,opt
[ $? = 0 ] && {
	mkdir -p ~/rpmbuild/{SPECS,SOURCES}
	find ~/rpmbuild/RPMS/ -name "${pkgName}-*.rpm"|xargs rm -f
	cp ${FTAR} ~/rpmbuild/SOURCES/.
	rpmbuild -bb bkr-client-improved.spec 
}

rm -rf sysroot
cp ~/rpmbuild/RPMS/*/${pkgName}*.rpm $OPWD/.
rm ${FTAR}

