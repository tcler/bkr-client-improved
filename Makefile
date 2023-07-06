
export PATH:=${PATH}:/usr/local/bin:~/bin
_bin=/usr/local/bin
_lib=/usr/local/lib
_share=/usr/share/bkr-client-improved
_confdir=/etc/bkr-client-improved
completion_path=/usr/share/bash-completion/completions

install install_runtest: _isroot yqinstall install_kiss_vm_ns
	@if [[ $$(rpm -E %rhel) != "%rhel" ]]; then \
	  if ! rpm -q epel-release; then \
	    rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-$$(rpm -E %rhel).noarch.rpm; :; \
	  fi; \
	fi
	@rpm -q beaker-client || utils/beaker-client_install.sh
	@yum install -y rhts-devel
	@rpm -q rhts-devel || { cp repos/beaker-harness.repo /etc/yum.repos.d/.; yum install -y restraint-rhts; }
	@rpm -q expect >/dev/null || yum install -y expect #package that in default RHEL repo
	@yum install -y tcllib #epel
	@yum install -y tdom || yum-install-from-fedora.sh tdom || :
	@-! tclsh <<<"lappend ::auto_path $(_lib) /usr/lib64; package require tdom" 2>&1|grep -q 'can.t find' || \
		{ rpm -q tdom &>/dev/null || ./utils/tdom_install.sh; }
	@rpm -q procmail >/dev/null || yum install -y procmail #package that in default RHEL repo
	mkdir -p $(_confdir) && cp -f conf/*.example $(_confdir)/.
	test -f $(_confdir)/bkr-runtest.conf || cp $(_confdir)/bkr-runtest.conf{.example,}
	test -f $(_confdir)/bkr-autorun.conf || cp $(_confdir)/bkr-autorun.conf{.example,}
	test -f $(_confdir)/default-ks.cfg || cp $(_confdir)/default-ks.cfg{.example,}
	sed -i -e 's/defaultHarness/Harness/g' -e 's/defaultOSInstaller/OSInstaller/g' $(_confdir)/bkr-runtest.conf
	test -f /etc/beaker/default-ks.cfg || mv $(_confdir)/default-ks.cfg /etc/beaker/.
	wget -qO- http://api.github.com/repos/tcler/bkr-client-improved/commits/master -O $(_confdir)/version || :
	cd lib; for d in *; do rm -fr $(_lib)/$$d; done
	cd utils; for f in *; do rm -fr $(_bin)/$$f; done
	cd bkr-runtest; for f in *; do rm -fr $(_bin)/$$f; done
	cp -rf -d lib/* $(_lib)/.
	cp -f -d bkr-runtest/* utils/* $(_bin)/.
	mkdir -p $(_share) && cp -f share/* $(_share)/.
	@yum install -y bash-completion
	cp -fd bash-completion/* ${completion_path}/.||cp -fd bash-completion/* $${completion_path/\/*/}/.
	@rm -f /usr/lib/python2.7/site-packages/bkr/client/commands/cmd_recipes_list.py $(_bin)/distro-pkg #remove old file
	@rm -f $(_bin)/{distro-to-vm.sh,downloadBrewBuild,installBrewPkg,yaml2dict} #remove old file

yqinstall: _isroot
	./utils/yq-install.sh

install_kiss_vm_ns: _isroot
	@command -v kiss-update.sh && kiss-update.sh || { \
	rm -rf kiss-vm-ns; command -v git || yum install -y git; \
	export https_proxy=squid.redhat.com:8080; git clone https://github.com/tcler/kiss-vm-ns; \
	make -C kiss-vm-ns; \
	rm -rf kiss-vm-ns; }

install_all: install_robot _install_web

install_robot: _isroot install_runtest _install_require
	#install test robot
	cd bkr-test-robot; for f in *; do [ -d $$f ] && continue; cp -fd $$f $(_bin)/$$f; done

_install_web: _isroot _web_require
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

_install_require: _isroot
	@sed -i '/^Defaults *secure_path/{/.usr.local.bin/! {s; *$$;:$(_bin);}}' /etc/sudoers
	@rpm -q tcl-devel >/dev/null || yum install -y tcl-devel #package that in default RHEL repo
	@rpm -q sqlite >/dev/null || yum install -y sqlite #package that in default RHEL repo
	@rpm -q sqlite-tcl >/dev/null || { yum install -y sqlite-tcl; exit 0; } #package that in default RHEL repo

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }

_web_require:
	@test `rpm -E %fedora` != %fedora || test `rpm -E '%rhel'` -ge 8 || \
		{ echo "[Warn] only support Fedora and RHEL-8+" >&2; exit 1; }

rpm: _isroot
	./build_rpm.sh

p pu pull u up update:
	git pull --rebase || :
	@echo

