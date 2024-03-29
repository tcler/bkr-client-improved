#!/bin/bash

rtype=rel-eng
rtype=nightly
downhostname=download.devel.redhat.com
verx=$(rpm -E %rhel)
case $verx in
8|9)
	buildrootUrl=http://$downhostname/rhel-$verx/$rtype/BUILDROOT-$verx/latest-BUILDROOT-$verx-RHEL-$verx/compose/Buildroot/$(arch)/os/
	echo $buildrootUrl >&2
	cat <<-EOF >/etc/yum.repos.d/beaker-buildroot.repo
	[beaker-buildroot]
	name=beaker-buildroot
	baseurl=$buildrootUrl
	enabled=1
	gpgcheck=0
	skip_if_unavailable=1
	EOF
	;;
esac

