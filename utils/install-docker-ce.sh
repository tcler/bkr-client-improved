#!/bin/bash

# see: https://kubernetes.io/docs/setup/cri
# test pass on RHEL-7.5 RHEL-7.6 RHEL-8.0

# Install Docker CE for CentOS/RHEL 7.5+

## Set up the repository
### Install required packages.
yum install -y container-selinux
rpm -q container-selinux || {
	url=http://mirror.centos.org/centos/7/extras/x86_64/Packages
	pkg=$(curl -s -L $url | egrep '\<container-selinux-[-.1-9a-z]+' -o | head -n1)
	yum install -y $url/$pkg
}

yum install -y yum-utils device-mapper-persistent-data lvm2

### Add docker repository.
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

## Install docker ce.
yum update && yum install -y docker-ce-18.06.1.ce

## Create /etc/docker directory.
mkdir /etc/docker

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
