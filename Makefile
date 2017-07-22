
export PATH:=${PATH}:/usr/local/bin:~/bin
_bin=/usr/local/bin
_bkr_client_cmd=/usr/lib/python2.7/site-packages/bkr/client/commands
completion_path=/usr/share/bash-completion/completions

install install_runtest: _isroot
	@rpm -q redhat-lsb >/dev/null || yum install -y redhat-lsb #package that in default RHEL repo
	@if [[ $$(lsb_release -si) != Fedora ]]; then \
	  if ! rpm -q epel-release; then \
	    [[ $$(uname -r) =~ ^2\.6\. ]] && rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm; \
	    [[ $$(uname -r) =~ ^3\. ]] && rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm; \
	  fi; \
	fi
	@rpm -q tcl >/dev/null || yum install -y tcl #package that in default RHEL repo
	@yum install -y tcllib  #epel
	@rpm -q procmail >/dev/null || yum install -y procmail #package that in default RHEL repo
	mkdir -p /etc/bkr-client-improved && cp -n -r -d conf/* /etc/bkr-client-improved/.
	cd lib; for d in *; do rm -fr /usr/local/lib/$$d; done
	cd utils; for f in *; do rm -fr $(_bin)/$$f; done
	cd bkr-runtest; for f in *; do rm -fr $(_bin)/$$f; done
	cp -rf -d lib/* /usr/local/lib/.
	cp -f -d bkr-runtest/* utils/* $(_bin)/.
	@ps axf|grep -v grep|grep -q vershow || $(_bin)/vershow -uu >/dev/null &
	cp -f -d bash-completion/* $(completion_path)/.
	@-cp -f bkr-client-cmd/* $(_bkr_client_cmd)/.

install_all: install_robot _install_web

install_robot: _isroot install_runtest _install_require
	#install test robot
	cd bkr-test-robot; for f in *; do [ -d $$f ] && continue; cp -fd $$f $(_bin)/$$f; done

_install_web: _isroot _install_tclsh8.6
	#install webfront
	[ -d /opt/wub ] || { \
	yum install -y svn &>/dev/null; \
	svn export https://github.com/tcler/wub/trunk /opt/wub >/dev/null; }
	cd bkr-test-robot/www2; for f in *; do rm -fr /opt/wub/docroot/$$f; done
	cp -rf -d bkr-test-robot/www2/* /opt/wub/docroot/.
	@chmod o+w /opt/wub/CA
	@chmod u+s /usr/local/bin/wub-service.sh

_install_web1: _isroot _install_tclsh8.6
	#install webfront
	[ -d /opt/wub ] || { \
	yum install -y svn &>/dev/null; \
	svn export https://github.com/tcler/wub/trunk /opt/wub >/dev/null; }
	cd bkr-test-robot/www; for f in *; do rm -fr /opt/wub/docroot/$$f; done
	cp -rf -d bkr-test-robot/www/* /opt/wub/docroot/.
	@chmod o+w /opt/wub/CA
	@chmod u+s /usr/local/bin/wub-service.sh

_install_tclsh8.6: _isroot
	@which tclsh8.6 || { ./utils/tcl8.6_install.sh; }

_install_require: _isroot
	@sed -i '/^Defaults *secure_path/{/.usr.local.bin/! {s; *$$;:$(_bin);}}' /etc/sudoers
	@rpm -q tcl-devel >/dev/null || yum install -y tcl-devel #package that in default RHEL repo
	@rpm -q sqlite >/dev/null || yum install -y sqlite #package that in default RHEL repo
	@rpm -q sqlite-tcl >/dev/null || { yum install -y sqlite-tcl; exit 0; } #package that in default RHEL repo
	@-! tclsh <<<"lappend ::auto_path /usr/local/lib /usr/lib64; package require tdom" 2>&1|grep -q 'can.t find' || \
{ yum install -y tdom || ./utils/tdom_install.sh; }

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }

rpm: _isroot
	./build_rpm.sh
