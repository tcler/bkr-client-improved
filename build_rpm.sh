#!/bin/sh
# to build the bkr-client-improved rpm and update.
# autor: jiyin@redhat.com

OPWD=$PWD
cd $(dirname ${0})
pkgName="bkr-client-improved"

configToCompatRhel5() {
	local ni=i p=
	[ $# -gt 0 ] && { ni=n; p=p; }
	sed -r -$ni -e '/#+%_(source|binary)_payload/{s/#+//g;'$p'}' /usr/lib/rpm/macros
	sed -r -$ni -e '/^%_(source|binary)_.*_algorithm/{s/^/#/;'$p'}' -e '/^%_binary_payload/{s/^/#/g;'$p'}' /usr/lib/rpm/redhat/macros
}
unconfigToCompatRhel5() {
	local ni=i p=
	[ $# -gt 0 ] && { ni=n; p=p; }
	sed -r -$ni -e '/^%_(source|binary)_payload/{s/^/#/g;'$p'}' /usr/lib/rpm/macros
	sed -r -$ni -e '/#+%_(source|binary)_.*_algorithm/{s/#+//g;'$p'}' -e '/#+%_binary_payload/{s/#+//g;'$p'}' /usr/lib/rpm/redhat/macros
}
rpmBild() {
	local ftar=${1%%,*}
	local dirList=${1#*,}

    configToCompatRhel5
	pushd sysroot >/dev/null

	tar zcf $ftar ${dirList//,/ }
	chmod +x ./usr/local/bin/tgz2rpm.sh
	echo -e "#========> Delete old version rpm <========#\n"
	echo -e "#========> Begin  build  new  rpm <========#"
	rm -f ~/rpmbuild/RPMS/*/${ftar%-*}-*.rpm
	./usr/local/bin/tgz2rpm.sh $ftar
	mv $ftar ../.; cd ..

	popd >/dev/null
    unconfigToCompatRhel5
}

mkdir -p sysroot/usr/local/{src,lib,bin} sysroot/etc
cp -arf lib/*  sysroot/usr/local/lib/.
cp -af bkr/* utils/* cron_task/* sysroot/usr/local/bin/.
cp -af conf/* sysroot/etc/.

rpmBild  ${pkgName}-0.12.129.tar.gz,usr,etc,var,opt

rm -rf sysroot
cp ~/rpmbuild/RPMS/*/${pkgName}*.rpm $OPWD/.
rm ${pkgName}*.tar.gz
