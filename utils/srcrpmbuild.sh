#!/bin/bash

which rpmbuild &>/dev/null || yum install -y /usr/bin/rpmbuild

pkg=$1
buildtype=${2:-p}

[[ "$buildtype" = b ]] && {
	which gcc &>/dev/null || yum install -y gcc
}

mkdir -p ~/rpm/build
rm -rf ~/rpmbuild/*
rpm -ivh $pkg
rpmbuild -b${buildtype} ~/rpmbuild/SPECS/*.spec

if [[ "$buildtype" = p ]]; then
	mv -f ~/rpmbuild/BUILD/* ./.
elif [[ "$buildtype" = b ]]; then
	mv -f ~/rpmbuild/RPMS/x86_64/* ./.
fi
