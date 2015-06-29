
softinstall install: isroot install_require install_wub
	cp -an conf/* /etc/.
	(cd lib; for d in *; do rm -rf /usr/local/lib/$$d; ln -sf -T $$PWD/$$d /usr/local/lib/$$d; done)
	(cd bkr; for f in *; do ln -sf -T $$PWD/$$f /usr/local/bin/$$f; done)
	(cd utils; for f in *; do ln -sf -T $$PWD/$$f /usr/local/bin/$$f; done)
	(cd www; for f in *; do ln -sf -T $$PWD/$$f /opt/wub/docroot/$$f; done)

hardinstall: isroot install_require install_wub
	cp -an conf/* /etc/.
	cd lib; for d in *; do rm -fr /usr/local/lib/$$d; done
	cp -arf lib/* /usr/local/lib/.
	cp -afl bkr/* utils/* /usr/local/bin/.
	cp -afl www/* /opt/wub/docroot/.

install_wub: isroot install_tclsh8.6
	@[ -d /opt/wub ] || { \
	wget http://download.devel.redhat.com/qa/rhts/lookaside/bkr-client-improved/wub.tar.bz2 -O /opt/wub.tar.bz2; \
	tar jxf /opt/wub.tar.bz2 -C /opt; }

install_tclsh8.6: isroot
	@which tclsh8.6 || { ./utils/tcl8.6_install.sh; }

install_require: isroot
	@rpm -q tcl || yum install -y tcl #package that in default RHEL repo
	@rpm -q tcl-devel || yum install -y tcl-devel #package that in default RHEL repo
	@rpm -q sqlite || yum install -y sqlite #package that in default RHEL repo
	@rpm -q procmail || yum install -y procmail #package that in default RHEL repo
	@rpm -q sqlite-tcl || { yum install -y sqlite-tcl; exit 0; } #package that in default RHEL repo
	@-! tclsh <<<"lappend ::auto_path /usr/lib /usr/lib64; package require md5" 2>&1|grep -q 'can.t find' || \
{ yum install -y tcllib || ./utils/tcllib_install.sh; }
	@-! tclsh <<<"lappend ::auto_path /usr/local/lib /usr/lib64; package require tdom" 2>&1|grep -q 'can.t find' || \
{ yum install -y tdom || ./utils/tdom_install.sh; }
	@ps axf|grep -v grep|grep -q vershow || vershow -uu &

rpm: isroot
	./build_rpm.sh

isroot:
	@test `id -u` = 0 || { echo "[Warn] need root permission" >&2; exit 1; }
