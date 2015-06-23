#!/bin/bash

pkg=$1

mkdir -p ~/rpm/build
rm -rf ~/rpmbuild/*
rpm -ivh $pkg
rpmbuild -bp ~/rpmbuild/SPECS/*.spec --nodeps
mv ~/rpmbuild/BUILD/* .
