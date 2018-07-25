Summary: Beaker client improved
Name:    bkr-client-improved
Version: 0.99
Release: 0
Group:   System
URL:     https://github.com/tcler/bkr-client-improved
License: GPL
Vendor:  Freeman
BuildArch: noarch
BuildRoot: /var/tmp/%{name}-buildroot

# Tests need the testing env package to be runnable:
Requires: tcllib sqlite-tcl tdom procmail

# Provides/Requires for test 
Provides: test

AutoReqProv: no:

Source0: %{name}-%{version}.tar.gz

%description
A improved beaker client tools: 

%prep

%setup -c -n %{name}-%{version}

%build

%install
[ -d ${RPM_BUILD_ROOT} ] && rm -rf ${RPM_BUILD_ROOT}
/bin/mkdir -p ${RPM_BUILD_ROOT}
/bin/cp -axv ${RPM_BUILD_DIR}/%{name}-%{version}/* ${RPM_BUILD_ROOT}/

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
chmod u+s /usr/local/bin/wub-service.sh

%postun

%clean

%files
%defattr(-,root,root)
/etc/bkr-client-improved/bkr-autorun.conf
/etc/bkr-client-improved/bkr.recipe.matrix.conf
/etc/bkr-client-improved/bkr.recipe.matrix.conf.example
/etc/bkr-client-improved/subtest.desc.example
/etc/bkr-client-improved/bkr-runtest.conf
/usr/local/bin/bkr-job-result2list
/usr/local/bin/ircmsg.sh
/usr/local/bin/needinfome.sh
/usr/local/bin/_brew.sh
/usr/local/bin/_getNicIp.sh
/usr/local/bin/availableHost.sh
/usr/local/bin/bkr-autorun-create
/usr/local/bin/bkr-autorun-del
/usr/local/bin/bkr-autorun-monitor
/usr/local/bin/bkr-autorun-stat
/usr/local/bin/bkr-autorun-update-md5
/usr/local/bin/bkr-reservesys
/usr/local/bin/bkr-runtest
/usr/local/bin/build_krb5_server.sh
/usr/local/bin/build_nis_server.sh
/usr/local/bin/config_krb5_client.sh
/usr/local/bin/config_nis_client.sh
/usr/local/bin/distro-list.sh
/usr/local/bin/downloadBrewBuild
/usr/local/bin/errata2distro_and_pkg
/usr/local/bin/errataInfo
/usr/local/bin/expand_testlist
/usr/local/bin/gen_job_xml
/usr/local/bin/getDefaultIp
/usr/local/bin/getDefaultNic
/usr/local/bin/getIp
/usr/local/bin/getLatestRHEL
/usr/local/bin/installBrewPkg
/usr/local/bin/klogin
/usr/local/bin/latestDistro.sh
/usr/local/bin/latestKernel.sh
/usr/local/bin/lscolor.sh
/usr/local/bin/lstest
/usr/local/bin/newcase.sh
/usr/local/bin/nolimit.sh
/usr/local/bin/packInstalledRpm.sh
/usr/local/bin/parse_netqe_nic_info.sh
/usr/local/bin/pushcase.sh
/usr/local/bin/recipe.sh
/usr/local/bin/runtest
/usr/local/bin/searchBrewBuild
/usr/local/bin/sendmail.sh
/usr/local/bin/sortV
/usr/local/bin/srcrpmbuild.sh
/usr/local/bin/sshbkr
/usr/local/bin/stateBrewBuild
/usr/local/bin/tcl8.6_install.sh
/usr/local/bin/tcllib_install.sh
/usr/local/bin/tdom_install.sh
/usr/local/bin/vercmp
/usr/local/bin/vershow
/usr/local/bin/wub-service.sh
/usr/local/bin/xmlrpc-client.sh
/usr/local/lib/getOpt-1.0/example.tcl
/usr/local/lib/getOpt-1.0/getOpt.tcl
/usr/local/lib/getOpt-1.0/pkgIndex.tcl
/usr/local/lib/runtestlib-1.0/pkgIndex.tcl
/usr/local/lib/runtestlib-1.0/runtestlib.tcl
/usr/local/lib/xmlgen-1.4/htmlgen.tcl
/usr/local/lib/xmlgen-1.4/pkgIndex.tcl
/usr/local/lib/xmlgen-1.4/sidenav.tcl
/usr/local/lib/xmlgen-1.4/tab.tcl
/usr/local/lib/xmlgen-1.4/xmlgen.tcl

%define date  %(echo `LC_ALL="C" date +"%a %b %d %Y"`)

%changelog

* %{date} User <jiyin@redhat.com>
- first Version

