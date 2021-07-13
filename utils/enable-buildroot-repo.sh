#!/bin/bash

verx=$(rpm -E %rhel)
case $verx in
8|9)
	[[ "$verx" = 8 ]] && R8=-RHEL-8
	[[ "$verx" = 9 ]] && stype=-Beta
	read dtype distro <<< $(awk -F/+ '/^baseurl/ {
		for (i=3;i<NF;i++) {
			if ($(i+1) ~ /RHEL-/) {
				d=$(i+1)
				if (d ~ /RHEL-[0-9]$/) {
					d=$(i+2)
				}
				print($i, d)
				break
			}
		}
	}' /etc/yum.repos.d/beaker-BaseOS.repo)

	dtype=nightly
	read prefix ver time <<< ${distro//-/ }
	buildrootUrl=http://download.devel.redhat.com/rhel-$verx/$dtype/BUILDROOT-$verx$stype/latest-BUILDROOT-$ver$R8/compose/Buildroot/$(arch)/os
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

