#!/bin/bash

verx=$(rpm -E %rhel)
case $verx in
8|9)
	baserepofile=$(grep BaseOS$ -r /etc/yum.repos.d/ -l)
	url=$(awk '/^baseurl/{print $3}' $baserepofile)
	echo $url >&2
	{ read; read os arch osv ver _; } < <(tac -s ' ' <<<"${url//\// }")
	debug_url=${url/\/os/\/debug\/tree}
	read dtype distro <<< $(awk -F/+ '{
		for (i=3;i<NF;i++) { if ($(i+1) ~ /RHEL-/) {
			d=$(i+1)
			if (d ~ /RHEL-[0-9]$/) d=$(i+2)
			print($i, d); break }
		}
	}' <<<"$url")
	read prefix ver time <<< ${distro//-/ }
	[[ "$dtype" =~ rel-eng|nightly ]] || dtype=nightly

	downhostname=download.devel.redhat.com
	if [[ $verx = 8 ]]; then
		buildrootUrl=http://$downhostname/rhel-$verx/$dtype/BUILDROOT-$verx/latest-BUILDROOT-$ver-RHEL-$verx/compose/Buildroot/$(arch)/os
	elif [[ $verx = 9 ]]; then
		dtype=nightly
		buildrootUrl=http://$downhostname/rhel-$verx/$dtype/BUILDROOT-$verx/latest-BUILDROOT-$verx-RHEL-$verx/compose/Buildroot/$(arch)/os
	fi

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

