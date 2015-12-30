export PATH:=${PATH}:/usr/local/bin:~/bin
_bin=/usr/local/bin

install install_runtest: _isroot
	@rpm -q redhat-lsb >/dev/null || yum install -y redhat-lsb #package that in default RHEL repo
	@rpm -q tcl >/dev/null || yum install -y tcl #package that in default RHEL repo
	@rpm -q procmail >/dev/null || yum install -y procmail #package that in default RHEL repo
	mkdir -p /etc/bkr-client-improved && cp -n -r -d conf/* /etc/bkr-client-improved/.
	cd lib; for d in *; do rm -fr /usr/local/lib/$$d; done
	cd utils; for f in *; do rm -fr $(_bin)/$$f; done
	cd bkr-runtest; for f in *; do rm -fr $(_bin)/$$f; done
	cp -rf -d lib/* /usr/local/lib/.
	cp -f -d bkr-runtest/* utils/* $(_bin)/.
	@chmod u+s /usr/local/bin/wub-service.sh
	@ps axf|grep -v grep|grep -q vershow || $(_bin)/vershow -uu >/dev/null &

install_all install_robot: _isroot install_runtest _install_tclsh8.6 _install_require
	#install test robot
	cd bkr-test-robot; for f in *; do [ -d $$f ] && continue; cp -fd $$f $(_bin)/$$f; done
	#install webfront
	[ -d /opt/wub ] || { \
	yum install -y svn &>/dev/null; \
	svn export https://github.com/tcler/wub/trunk /opt/wub >/dev/null; }
	(cd bkr-test-robot/www; for f in *; do ln -sf -T $$PWD/$$f /opt/wub/docroot/$$f; done)
	cd bkr-test-robot/www; for f in *; do rm -fr /opt/wub/docroot/$$f; done
	cp -rf -d bkr-test-robot/www/* /opt/wub/docroot/.
	@chmod o+w /opt/wub/CA

_install_tclsh8.6: _isroot
	@which tclsh8.6 || { ./utils/tcl8.6_install.sh; }

_install_require: _isroot
	@sed -i '/^Defaults *secure_path/{/.usr.local.bin/! {s; *$$;:$(_bin);}}' /etc/sudoers
	@rpm -q tcl-devel >/dev/null || yum install -y tcl-devel #package that in default RHEL repo
	@rpm -q sqlite >/dev/null || yum install -y sqlite #package that in default RHEL repo
	@rpm -q sqlite-tcl >/dev/null || { yum install -y sqlite-tcl; exit 0; } #package that in default RHEL repo
	@-! tclsh <<<"lappend ::auto_path /usr/lib /usr/lib64; package require md5" 2>&1|grep -q 'can.t find' || \
{ yum install -y tcllib || ./utils/tcllib_install.sh; }
	@-! tclsh <<<"lappend ::auto_path /usr/local/lib /usr/lib64; package require tdom" 2>&1|grep -q 'can.t find' || \
{ yum install -y tdom || ./utils/tdom_install.sh; }

_isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }

rpm: _isroot
	./build_rpm.sh
