#!/bin/bash
# vim: sts=4 sw=4 et
# package test case to beaker task library, support multiple dir
# author: zhchen@redhat.com

DIR="${@:-.}"

for d in $DIR; do
    test -f $d && d=${d%/*}
    test -d $d && {
        pushd $d &>/dev/null
            pwd
            make tag && git push --tags && make bkradd
        popd &>/dev/null
    }
done
