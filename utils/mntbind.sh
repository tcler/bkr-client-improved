#!/bin/bash

export LANG=C
while read dst src drop; do
	dev=${src%\[/*}
	rpath=${src##*\[/}; rpath=${rpath%]}
	rootdir=$(findmnt --list | awk -v dev=$dev '$2 == dev && $1 != "/" {print $1}')
	echo $dst $'\t' ${rootdir}/${rpath/\/\/deleted/ #-deleted}
done < <(findmnt --list | awk '$2 ~ /\]$/')
