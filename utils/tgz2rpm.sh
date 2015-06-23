#!/bin/bash
# This script creates an RPM from a tar file.
# $1 : tar file
# code from google. modified by yinjianhong to build a rpm

FTAR=$1
NAME=$(echo ${1%-*} | sed 's/^.*\///')
VERSION=$(echo ${1##*-} | sed 's/[^0-9]*$//')
RELEASE=0
VENDOR="RedHat"
EMAIL="<jiyin@redhat.com>"
SUMMARY="Beaker client improved"
LICENSE="GPL"
GROUP="System"
ARCH="noarch"
DESCRIPTION="A improved beaker client tools: "

######################################################
# users should not change the script below this line.#
######################################################

# This function prints the usage help and exits the program.
usage(){
    /bin/cat << USAGE

This script has been released under BSD license. Copyright (C) 2010 Reiner Rottmann <rei..rATrottmann.it>

$0 creates a simple RPM spec file from the contents of a tarball. The output may be used as starting point to create more complex RPM spec files.
The contents of the tarball should reflect the final directory structure where you want your files to be deployed. As the name and version get parsed
from the tarball filename, it has to follow the naming convention "<name>-<ver.si.on>.tar.gz". The name may only contain characters from the range
[-_a-zA-Z]. The version string may only include numbers seperated by dots.

Usage: $0  [TARBALL]

Example:
  $ $0 sample-1.0.0.tar.gz
  
  $ /usr/bin/rpmbuild -ba /tmp/sample-1.0.0.spec 

USAGE
    exit 1    
}

if echo "${1##*/}" | sed 's/[^0-9]*$//' | /bin/grep -q  '^[-_a-zA-Z]\+-[0-9.]\+$'; then
   if /usr/bin/file -ib "$1" | /bin/grep -q "application/x-gzip"; then
      echo "INFO: Valid input file '$1' detected."
   else
      usage
   fi
else
    usage
fi

OUTPUT=/tmp/${NAME}-${VERSION}.spec

FILES=$(/bin/tar -tzf $1 | /bin/grep -v '^.*/$' | sed 's/^/\//')

/bin/cat > $OUTPUT << EOF
Summary: $SUMMARY
Name:    $NAME
Version: $VERSION
Release: $RELEASE
Group:   $GROUP
URL:     FAKEURL
License: $LICENSE
Vendor:  $VENDOR
BuildArch: $ARCH
BuildRoot: /var/tmp/%{name}-buildroot

# Tests need the testing env package to be runnable:
Requires: tcllib sqlite-tcl tdom procmail

# Provides/Requires for test 
Provides: test

AutoReqProv: no:

Source0: %{name}-%{version}.tar.gz

%description
$DESCRIPTION

%prep

%setup -c -n %{name}-%{version}

%build

%install
[ -d \${RPM_BUILD_ROOT} ] && rm -rf \${RPM_BUILD_ROOT}
/bin/mkdir -p \${RPM_BUILD_ROOT}
/bin/cp -axv \${RPM_BUILD_DIR}/%{name}-%{version}/* \${RPM_BUILD_ROOT}/

%post
grep -q "/usr/local/bin/vershow" /etc/crontab || echo "  10 05 *  *  * root       /usr/local/bin/vershow -uu;" >>/etc/crontab
tar zxf /var/cache/distroInfoDB.tar.gz -C /var/cache
tar zxf /opt/wub.tar.gz -C /opt
which tclsh8.6 >/dev/null || {
	yum install -y gcc tcl tcl-devel
	/usr/local/bin/tcl8.6_install.sh
	/usr/local/bin/tcllib_install.sh
	/usr/local/bin/tdom_install.sh
}

%postun

%clean

%files
%defattr(-,root,root)
$FILES

%define date  %(echo \`LC_ALL="C" date +"%a %b %d %Y"\`)

%changelog

* %{date} User $EMAIL
- first Version

EOF

echo "INFO: Spec file has been saved as '$OUTPUT':"
echo "----------%<----------------------------------------------------------------------"
/bin/cat $OUTPUT
echo "----------%<----------------------------------------------------------------------"
[ -f "$FTAR" ] && {
	mkdir -p ~/rpmbuild/{SPECS,SOURCES}
	find ~/rpmbuild/RPMS/ -name ${NAME}-*.rpm|xargs rm -f
	cp $OUTPUT ~/rpmbuild/SPECS/.
	cp $FTAR ~/rpmbuild/SOURCES/.
	rpmbuild -bb ~/rpmbuild/SPECS/${OUTPUT##*/}
}

