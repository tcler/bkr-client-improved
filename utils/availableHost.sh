#!/bin/bash
# author jiyin@redhat.com

available_host() {
	for arch in x86_64 ppc64 s390x i386 ppc64le aarch64 armhfp; do
		echo "${arch}_host $(bkr list-systems --available --arch=$arch | wc -l)"
	done
}

available_host
