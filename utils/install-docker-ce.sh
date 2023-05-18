#!/bin/bash

# Install Docker CE for CentOS/RHEL 7.3+
# see: https://kubernetes.io/docs/setup/cri
# test pass on RHEL-7.3+ RHEL-8.0

if [[ "$(uname -m)" != x86_64 ]]; then
	echo "{WARN} only x86_64 version is provided."
	exit 1
fi

echo -e "{Note} docker-ce is deprecated on RHEL, please use 'podman' instead\n"

## Set up the repository
### Install required packages.
yum install -y container-selinux
rpm -q container-selinux || {
	url=http://mirror.centos.org/centos/7/extras/x86_64/Packages
	pkg=$(curl -s -L $url | grep -E '\<container-selinux-[-_.0-9a-z]+' -o | head -n1)
	yum install -y $url/$pkg
}
rpm -q container-selinux || {
	yum install -y redhat-lsb-core >/dev/null
	url=http://vault.centos.org
	ver=$(curl -s -L $url | grep -E -o "\<$(lsb_release -sr)\.[0-9]+" | tail -n1)
	url=http://vault.centos.org/$ver/extras/x86_64/Packages
	pkg=$(curl -s -L $url | grep -E '\<container-selinux-[-_.0-9a-z]+' -o | head -n1)
	yum install -y $url/$pkg
}

yum install -y yum-utils device-mapper-persistent-data lvm2

### Add docker repository.
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

## Install docker ce.
yum update -y && yum install -y docker-ce-18.06.1.ce

## Create /etc/docker directory.
mkdir -p /etc/docker

# Setup daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker
