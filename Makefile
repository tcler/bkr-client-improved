
export PATH:=${PATH}:/usr/local/bin:~/bin
_bin=/usr/local/bin
_lib=/usr/local/lib
_share=/usr/share/bkr-client-improved
_confdir=/etc/bkr-client-improved
completion_path=/usr/share/bash-completion/completions

install install_runtest: _isroot install_kiss_vm_ns
	@rpm -q redhat-lsb >/dev/null || yum install -y redhat-lsb #package that in default RHEL repo
	@if [[ $$(lsb_release -si) != Fedora ]]; then \
	  if ! rpm -q epel-release; then \
	    [[ $$(uname -r) =~ ^2\.6\. ]] && rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm; \
	    [[ $$(uname -r) =~ ^3\. ]] && rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm; :; \
	    [[ $$(uname -r) =~ ^4\. ]] && rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm; :; \
	  fi; \
	fi
	@rpm -q beaker-client || utils/beaker-client_install.sh
	@yum install -y rhts-devel
	@rpm -q rhts-devel || { cp repos/beaker-harness.repo /etc/yum.repos.d/.; yum install -y restraint-rhts; }
	@rpm -q tcl >/dev/null || yum install -y tcl #package that in default RHEL repo
	@yum install -y tcllib #epel
	@ rpm -q tcllib || yum install -y rpms/tcllib-1.19-2.el8.noarch.rpm #workaround for missing tcllib on RHEL-8
	@if [[ $$(lsb_release -si) != Fedora ]]; then \
	  libpath=$$(rpm -ql tcllib|egrep 'tcl8../tcllib-[.0-9]+$$'); ln -sf $${libpath} /usr/lib/$${libpath##*/}; \
	fi
	@rpm -q procmail >/dev/null || yum install -y procmail #package that in default RHEL repo
	mkdir -p $(_confdir) && cp -f conf/*.example $(_confdir)/.
	test -f $(_confdir)/bkr-runtest.conf || cp $(_confdir)/bkr-runtest.conf{.example,}
	test -f $(_confdir)/bkr-autorun.conf || cp $(_confdir)/bkr-autorun.conf{.example,}
	test -f $(_confdir)/default-ks.cfg || cp $(_confdir)/default-ks.cfg{.example,}
	sed -i -e 's/defaultHarness/Harness/g' -e 's/defaultOSInstaller/OSInstaller/g' $(_confdir)/bkr-runtest.conf
	test -f /etc/beaker/default-ks.cfg || cp -f conf/default-ks.cfg /etc/beaker/.
	cd lib; for d in *; do rm -fr $(_lib)/$$d; done
	cd utils; for f in *; do rm -fr $(_bin)/$$f; done
	cd bkr-runtest; for f in *; do rm -fr $(_bin)/$$f; done
	cp -rf -d lib/* $(_lib)/.
	cp -f -d bkr-runtest/* utils/* $(_bin)/.
	mkdir -p $(_share) && cp -f share/* $(_share)/.
	@yum install -y bash-completion
	cp -fd bash-completion/* ${completion_path}/.||cp -fd bash-completion/* $${completion_path/\/*/}/.
	@rm -f /usr/lib/python2.7/site-packages/bkr/client/commands/cmd_recipes_list.py $(_bin)/distro-pkg #remove old file
	@rm -f $(_bin)/{distro-to-vm.sh,downloadBrewBuild,installBrewPkg} #remove old file

install_kiss_vm_ns:
	@rm -rf kiss-vm-ns
	@git clone https://github.com/tcler/kiss-vm-ns
	@make -C kiss-vm-ns
	@rm -rf kiss-vm-ns

install_all: install_robot _install_web

install_robot: _isroot install_runtest _install_require
	#install test robot
	cd bkr-test-robot; for f in *; do [ -d $$f ] && continue; cp -fd $$f $(_bin)/$$f; done

_install_web: _isroot _install_tclsh8.6
	#install webfront
	[ -d /opt/wub2 ] || { \
	yum install -y svn nmap-ncat &>/dev/null; \
	svn export https://github.com/tcler/wub/trunk /opt/wub2 >/dev/null; }
	cd bkr-test-robot/www2; for f in *; do rm -fr /opt/wub2/docroot/$$f; done
	cp -rf -d bkr-test-robot/www2/* /opt/wub2/docroot/.
	cd /opt/wub2; sed -e 's;redirect /wub/;redirect /trms/;' \
		-e 's;^/wub/ ;/trms/ ;' \
		site.config >site-trms.config
	@chmod o+w /opt/wub2/CA
	@chmod u+s /usr/local/bin/trms-service.sh

_install_tclsh8.6: _isroot
	@which tclsh8.6 || { ./utils/tcl8.6_install.sh; }

_install_require: _isroot
	@sed -i '/^Defaults *secure_path/{/.usr.local.bin/! {s; *$$;:$(_bin);}}' /etc/sudoers
	@rpm -q tcl-devel >/dev/null || yum install -y tcl-devel #package that in default RHEL repo
	@rpm -q sqlite >/dev/null || yum install -y sqlite #package that in default RHEL repo
	@rpm -q sqlite-tcl >/dev/null || { yum install -y sqlite-tcl; exit 0; } #package that in default RHEL repo
	@-! tclsh <<<"lappend ::auto_path $(_lib) /usr/lib64; package require tdom" 2>&1|grep -q 'can.t find' || \
{ yum install -y tdom; \
rpm -q tdom &>/dev/null || yum install -y rpms/tdom-0.8.2-27.el8.x86_64.rpm; \
rpm -q tdom &>/dev/null || ./utils/tdom_install.sh; }

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }

rpm: _isroot
	./build_rpm.sh
