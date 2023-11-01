
export PATH:=${PATH}:/usr/local/bin:~/bin
_bin=/usr/local/bin
_lib=/usr/local/lib
_share=/usr/share/bkr-client-improved
_confdir=/etc/bkr-client-improved
completion_path=/usr/share/bash-completion/completions

HTTP_PROXY := $(shell grep -q redhat.com /etc/resolv.conf && echo "squid.redhat.com:8080")

install install_runtest: _isroot _rh_intranet yqinstall install_kiss_vm_ns
	@if [[ $$(rpm -E %rhel) != "%rhel" ]]; then \
	  if ! rpm -q epel-release; then \
	    rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-$$(rpm -E %rhel).noarch.rpm; :; \
	  fi; \
	fi
	@./utils/beaker-client_install.sh
	@yum install -y restraint-rhts restraint-client $$(yum -h|grep -o .--allowerasing)
	@rpm -q expect >/dev/null || yum install -y expect #package that in default RHEL repo
	@yum install -y tcllib #epel
	@yum install -y tdom || yum-install-from-fedora.sh tdom || :
	@-! tclsh <<<"lappend ::auto_path $(_lib) /usr/lib64; package require tdom" 2>&1|grep -q 'can.t find' || \
		{ rpm -q tdom &>/dev/null || ./utils/tdom_install.sh; }
	@rpm -q procmail >/dev/null || yum install -y procmail #package that in default RHEL repo
	mkdir -p $(_confdir) && cp -f conf/*.example conf/fetch-url.ini $(_confdir)/.
	@cp conf/default-ks.cfg.tmpl $(_confdir)/default-ks.cfg
	test -d /etc/beaker && ln -sf $(_confdir)/fetch-url.ini /etc/beaker/fetch-url.ini
	test -d /etc/beaker && ln -sf $(_confdir)/default-ks.cfg /etc/beaker/default-ks.cfg
	test -f $(_confdir)/bkr-runtest.conf || cp $(_confdir)/bkr-runtest.conf{.example,}
	test -f $(_confdir)/bkr-autorun.conf || cp $(_confdir)/bkr-autorun.conf{.example,}
	sed -i -e '/[Ff]etchUrl/d' -e 's/defaultOSInstaller/OSInstaller/g' $(_confdir)/bkr-runtest.conf
	curl -Ls http://api.github.com/repos/tcler/bkr-client-improved/commits/master -o $(_confdir)/version || :
	cd lib; for d in *; do rm -fr $(_lib)/$$d; done
	cd utils; for f in *; do rm -fr $(_bin)/$$f; done
	cd bkr-runtest; for f in *; do rm -fr $(_bin)/$$f; done
	cp -rf -d lib/* $(_lib)/.
	cp -f -d bkr-runtest/* utils/* $(_bin)/.
	mkdir -p $(_share) && cp -rf share/* $(_share)/.
	@yum install -y bash-completion
	cp -fd bash-completion/* ${completion_path}/.||cp -fd bash-completion/* $${completion_path/\/*/}/. || :
	@rm -f /usr/lib/python2.7/site-packages/bkr/client/commands/cmd_recipes_list.py $(_bin)/distro-pkg #remove old file
	@rm -f $(_bin)/{distro-to-vm.sh,downloadBrewBuild,installBrewPkg,yaml2dict} #remove old file
	@grep -q '^StrictHostKeyChecking no' /etc/ssh/ssh_config || echo "StrictHostKeyChecking no" >>/etc/ssh/ssh_config

yqinstall: _isroot
	./utils/yq-install.sh

install_kiss_vm_ns: _isroot
	-command -v kiss-update.sh && kiss-update.sh || ./utils/kiss-vm-ns_install.sh

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

_install_require: _isroot _rh_intranet
	@sed -i '/^Defaults *secure_path/{/.usr.local.bin/! {s; *$$;:$(_bin);}}' /etc/sudoers
	@rpm -q tcl-devel >/dev/null || yum install -y tcl-devel #package that in default RHEL repo
	@rpm -q sqlite >/dev/null || yum install -y sqlite #package that in default RHEL repo
	@rpm -q sqlite-tcl >/dev/null || { yum install -y sqlite-tcl; exit 0; } #package that in default RHEL repo

_rh_intranet:
	@if ! host ipa.redhat.com &>/dev/null; then \
		tar -C / -zxf conf/rh-cert.tgz; update-ca-trust; \
		tar -C / -zxf conf/rh-nm-openvpn-profiles.tgz; nmcli c r; \
		{ echo -e "[Warn] you have not connected in redhat intranet."; \
		  echo -e " ref: https://redhat.service-now.com/help?id=kb_article_view&sysparm_article=KB0005424" >&2; exit 1; }; \
	fi

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }

_web_require:
	@test `rpm -E %fedora` != %fedora || test `rpm -E '%rhel'` -ge 8 || \
		{ echo "[Warn] only support Fedora and RHEL-8+" >&2; exit 1; }

rpm: _isroot
	./build_rpm.sh

u up update:
	https_proxy=$(HTTP_PROXY) git pull --rebase || :
	@echo
p pu push:
	https_proxy=$(HTTP_PROXY) git push origin master || :
	@echo

