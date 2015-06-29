#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh "$0" ${1+"$@"}

# Author: jiyin@redhat.com
# Like but better than "bkr workflow-xxx --dryrun", more functional and flexible
# gen_job_xml --help for detail

lappend ::auto_path /usr/local/lib /usr/lib64 /usr/lib
package require xmlgen
package require getOpt
package require runtestlib
namespace import ::xmlgen::* ::getOpt::* ::runtestlib::*

declaretags job whiteboard notify cc
declaretags recipeSet recipe and or not
declaretags distroRequires distro_name distro_variant distro_method distro_arch
declaretags hostRequires hostname arch system_type key_value
declaretags repos repo
declaretags partitions partition
declaretags ks_appends ks_append
declaretags watchdog
declaretags task params param

# global var
array set Opt {}
array set InvalidOpt {}
set NotOptions [list]
set OptionList {
	f             {arg y	help {#Specify a test list file}}
	cc            {arg m	help {#Notify additional e-mail address on job completion}}
	task          {arg m	help {#taskname(can specify more than one times)}}
	param         {arg m	help {#taskparam(can specify more than one times), use "mh-" prefix to set different value for multihost, example: --param=mh-key=val1,val2}}
	taskparam     {link param}
	distro        {arg m	help {#distroname(can specify more than one for multihost)}}
	variant       {arg y	help {#variant type}}
	wb            {arg y	help {#job whiteboard info}}
	whiteboard    {link wb}
	rwb           {arg y	help {#recipe whiteboard info}}
	arch          {arg y	help {#arch name}}
	repo          {arg m	help {#repo(can specify more than one times)}}
	install       {arg m	help {#pkgname(can specify more than one times)}}
	nvr           {arg m	help {#kernel pkg name(can specify more than one for multihost)}}
	dbgk          {arg n	help {#Use the debug kernel}}
	servers       {arg y	help {#acount of servers(for multihost)}}
	clients       {arg y	help {#acount of clients(for multihost)}}
	dr            {arg m	help {#distrorequire -dr=key="value"}}
	distrorequire {link dr}
	hr            {arg m	help {#hostrequire -hr=labcontroller="lab.example.com"}}
	hostrequire   {link hr}
	kv            {arg m	help {#keyvalue -kv=DISKSPACE>=100000, -kv=NETWORK=e1000}}
	keyvalue      {link kv}
	machine       {arg m	help {#Same as --hostrequire=hostname="$name", more than one for multi}}
	systype       {arg y	help {#system type (Machine, Laptop ...)}}
	part          {arg m	help {#partition: --part='fs=xfs name=/mnt/xfs size=10 type=part'}}
	partition     {link part}
	ormachine     {arg m	help {#beaker auto pick in specified machine list.}}

	nay-nic-driver  {arg o  help {#nic-driver condition for parse_nay_nic_info.sh to get network-qe hostnames in NAY lab}}
	nay-nic-model   {arg o  help {#nic-model condition for parse_nay_nic_info.sh to get network-qe hostnames in NAY lab}}
	nay-nic-speed   {arg o  help {#nic-speed condition for parse_nay_nic_info.sh to get network-qe hostnames in NAY lab}}
	nay-nic-pattern {arg o  help {#nic-pattern condition for parse_nay_nic_info.sh to get network-qe hostnames in NAY lab}}
	nay-nic-num     {arg o  help {#nic-num condition for parse_nay_nic_info.sh to get network-qe hostnames in NAY lab}}

	nay-driver    {link nay-nic-driver}
	nic-num       {link nay-nic-num}

	kcov          {arg n	help {#insert kcov task for do the kernel test coverage check}}
	kdump         {arg o	help {#insert kdump task for get core dump file if panic happen}}
	ks            {arg m	help {#Pass kickstart metadata OPTIONS when generating kickstart}}
	ks-meta       {link ks}
	ksf           {arg m	help {#Similar -ks, read kickstart data from file}}
	cmd           {arg m	help {#run command}}
	cmdb          {arg m	help {#run command before kernel install}}
	k-opts              {arg m	help {#Pass OPTIONS to kernel during installation}}
	kernel-options      {link k-opts}
	k-opts-post         {arg m	help {#Pass OPTIONS to kernel after installation}}
	kernel-options-post {link k-opts-post}
	opts-macro          {arg y	help {#exec the "cmd [arg]" in run time to generate options}}
	reserve-if-fail     {arg o	help {#Reserve the machine if test fail; time scope [1,356400]s accept m/h/d}}
	recipe        {arg n	help {#Just generate recipeSet node,for runtest -merge}}
	restraint     {arg o	help {#Use restraint test}}
	leap-second   {arg n	help {#leap second test}}
}

# _parse_ argument
getOptions $OptionList $::argv Opt InvalidOpt NotOptions
proc debug {} {
	puts "NotOptions: $NotOptions"
	parray InvalidOpt
	parray Opt
}

# process --param= option
set GlobalParam {}
if [info exist Opt(param)] { lappend GlobalParam {*}$Opt(param) }

# process --distro= option
set DISTRO_L {}
set _ldistro {}
if [info exist Opt(distro)] {
	foreach e $Opt(distro) {lappend _ldistro {*}[split $e ", "]}
	set prev {}
	foreach d $_ldistro {
		if {[string length $d] > 0} {
			lappend DISTRO_L $d
			set prev $d
		} elseif {[string length $prev] > 0} {
			lappend DISTRO_L $prev
		}
	}
	lappend GlobalParam "DISTRO_BUILD=$DISTRO_L"
}
if {[llength $DISTRO_L] == 0} {
	puts stderr "Warning: no distro specified, use --distro= option"
	getUsage $OptionList
	exit 1
}

# process -f or --task= option
set TaskList {}
set TestList {}
if [info exist Opt(task)] { lappend TestList {*}$Opt(task) }
if [info exist Opt(f)] {
	set fp stdin
	set testfile $Opt(f)
	if {$testfile ni "-"} { set fp [open $testfile] }
	while {-1 != [gets $fp line]} {
		lappend TestList $line
	}
	if {$testfile ni "-"} { close $fp }
}
if {[llength $TestList] == 0} {
	puts stderr "Warning: no task specified, use -f or --task= option"
	getUsage $OptionList
	exit 1
}
foreach T $TestList {
	lappend TaskList [concat [lindex $T 0] $GlobalParam [testinfo param $T]]
}

set METHOD "nfs"

set SystemType "Machine"
if [info exist Opt(systype)] { set SystemType $Opt(systype) }

set KVARIANT "up"
if [info exist Opt(dbgk)] { set KVARIANT "debug" }

set MACHINE_L {}
if [info exist Opt(machine)] {
	foreach e $Opt(machine) {lappend MACHINE_L {*}[split $e ", "]}
}

set ORMACHINE_L {}
if [info exist Opt(ormachine)] {
	foreach e $Opt(ormachine) {lappend ORMACHINE_L {*}[split $e ", "]}
}

set ARCH_L {auto}
if [info exist Opt(arch)] {
	set ARCH_L {}
	foreach e $Opt(arch) {lappend ARCH_L {*}[split $e ", "]}
}

set restraint {}
set restraint_git "git://pkgs.devel.redhat.com/tests"
set recipe_ks_meta {}
if [info exist Opt(restraint)] {
	set restraint "yes"
	set recipe_ks_meta {harness='restraint-rhts beakerlib'}
	if {$Opt(restraint) != ""} {
		if [regexp {^\?} $Opt(restraint)] {
			append restraint_git $Opt(restraint)
		} else {
			set restraint_git $Opt(restraint)
		}
	}
}

set ROLE_LIST {}
if [info exist Opt(servers)] { lappend ROLE_LIST {*}[lrepeat $Opt(servers) SERVERS] }
if [info exist Opt(clients)] { lappend ROLE_LIST {*}[lrepeat $Opt(clients) CLIENTS] }
if {[llength $ROLE_LIST] == 0} { set ROLE_LIST STANDALONE }

# handle NAY NIC machines
set nay_nic_opts {driver model speed pattern num}
foreach i $nay_nic_opts {
	if [info exist Opt(nay-nic-$i)] {
		set NAY_NIC_OPTS_DICT($i) [split $Opt(nay-nic-$i) ", "]
	}
}

set M 0
foreach role $ROLE_LIST {
	# set nay-nic machine list for different role
	if [info exist NAY_NIC_OPTS_DICT] {
		# init each params for parse_nay_nic_info.sh
		foreach i $nay_nic_opts { set $i {} }

		# get nay-nic-* options key-val for each role
		foreach key [array names NAY_NIC_OPTS_DICT] {
			set $key [lindex $NAY_NIC_OPTS_DICT($key) $M]
			eval set val $$key
			if {$val==""} {set $key [lindex $NAY_NIC_OPTS_DICT($key) 0]}
		}

		# set default values for parse_nay_nic_info.sh params
		if {$driver==""} {set driver any}
		if {$model==""} {set model any}
		if {$speed==""} {set speed any}
		if {$pattern==""} {set pattern any}
		if {$num==""} {set num 1}

		# get ormachine_list for each role
		set NAY_NIC_MACHINE($role) [exec parse_nay_nic_info.sh -d "$driver" -m "$model" -s "$speed" -p "$pattern" -c "$num"]
		incr M 1
	} {
		set NAY_NIC_MACHINE($role) {}
	}
}

set jobCtl {!}
set wbCtl {-}
set notifyCtl {!}
if [info exist Opt(recipe)] {
	set jobCtl {c}
	set wbCtl {_}
	set notifyCtl {C}
}

# start generate xml
job retention_tag=Scratch $jobCtl {
	if ![info exist Opt(wb)] {
		set Time [clock format [clock seconds] -format %Y-%m-%d~%H:%M]
		set Opt(wb) "\[$Time\] $DISTRO_L \\[llength $TaskList]/[file tail [lindex [lindex $TaskList 0] 0]],... arch=$ARCH_L "
	}
	whiteboard $wbCtl $Opt(wb)
	notify $notifyCtl {
		if [info exist Opt(cc)] {
			foreach e $Opt(cc) {
				foreach m [split $e ", "] { cc - $m }
			}
		}
	}
	recipeSet priority=Normal ! {
		set DISTRO {}
		set R {0};	# Role index
		foreach role ${ROLE_LIST} {
			if [llength $DISTRO_L] {
				set DISTRO [lindex $DISTRO_L 0]
				set DISTRO_L [lrange $DISTRO_L 1 end]
			}
			if [llength $ARCH_L] {
				set ARCH [lindex $ARCH_L 0]
				set ARCH_L [lrange $ARCH_L 1 end]
			}
			if ![string length $ARCH] {set ARCH auto}
			if [string equal $ARCH "auto"] {set ARCH x86_64}

			if ![info exist Opt(k-opts)] {set Opt(k-opts) ""}
			if ![info exist Opt(k-opts-post)] {set Opt(k-opts-post) ""}
			recipe kernel_options=$Opt(k-opts) kernel_options_post=$Opt(k-opts-post) whiteboard=$Opt(wb) ks_meta=$recipe_ks_meta ! {
				distroRequires ! {
					and ! {
						distro_name op== value=${DISTRO} -
						if [info exist Opt(variant)] {
							distro_variant op== value=$Opt(variant) -
						}
						distro_method op== value=${METHOD} -
						distro_arch op== value=${ARCH} -
						if [info exist Opt(dr)] {
							foreach kv $Opt(dr) {
								lassign [regsub (.*?)(=|!=|>|>=|<|<=)(.*$) $kv {\1 op=\2 {value=\3}}] k op v
								doTag $k $op $v -
							}
						}
					}
				}
				hostRequires ! {
					and ! {
						if [llength $MACHINE_L] {
							set MACHINE [lindex $MACHINE_L 0]
							set MACHINE_L [lrange $MACHINE_L 1 end]
						}

						if {[info exist MACHINE] && [string length $MACHINE] > 0} {
							hostname op== value=$MACHINE -
							if {$SystemType != "Machine"} {system_type op== value=${SystemType} -}
						} else {
							arch op== value=${ARCH} -
							system_type op== value=${SystemType} -
							if [info exist Opt(hr)] {
								foreach kv $Opt(hr) {
									lassign [regsub (.*?)(=|!=|>|>=|<|<=)(.*$) $kv {\1 op=\2 {value=\3}}] k op v
									doTag $k $op $v -
								}
							}
							if [info exist Opt(kv)] {
								foreach kv $Opt(kv) {
									lassign [regsub (.*?)(=|!=|>|>=|<|<=)(.*$) $kv {key=\1 op=\2 {value=\3}}] k op v vv
									doTag key_value $k $op $v -
								}
							}
						}
					}
					or ! {
						foreach m "$ORMACHINE_L $NAY_NIC_MACHINE($role)" {
							hostname op== value=${m} -
						}
					}
					not ! {
						#
					}
				}
				repos ! {
					if [info exist Opt(repo)] {
						foreach url $Opt(repo) {
							repo name=myrepo_[incr i] url=$url -
						}
					}
					if {$restraint == "yes"} {
						repo name=restraint url=http://file.bos.redhat.com/~bpeck/restraint/el7--test/ -
					}
				}
				partitions ! {
					if [info exist Opt(part)] {
						foreach part $Opt(part) {
							partition {*}$part -
						}
					}
				}

				ks_appends ! {
					if {[info exist Opt(nvr)] && [info exist Opt(repo)]} {
						ks_append ! {
							puts {<![CDATA[}
							puts {%post}
							set i 0
							foreach url $Opt(repo) {
								puts "cat <<-EOF >/etc/yum.repos.d/beaker-kernel$i.repo
								\[beaker-kernel$i\]
								name=beaker-kernel$i
								baseurl=$url
								enabled=1
								gpgcheck=0
								skip_if_unavailable=1
								EOF"
								incr i
							}
							puts {%end}
							puts -nonewline {]]>}
						}
					}

					if [info exist Opt(ksf)] {
						if {![catch {set fp [open $Opt(ksf)]} err]} {
							set data [read $fp]
							close $fp
							lappend Opt(ks) $data
						}
					}
					if [info exist Opt(ks)] {
						foreach ks $Opt(ks) {
							ks_append ! {
								puts {<![CDATA[}
								puts {%post}
								puts $ks
								puts {%end}
								puts -nonewline {]]>}
							}
						}
					}
				}

				if [info exist Opt(reserve-if-fail)] {watchdog panic=ignore -}

				# distro install
				task name=/distribution/install role=$role ! {
					params ! {
						param name=DISTRO_BUILD value=$DISTRO -
					}
				}

				# command before kernelinstall
				if [info exist Opt(cmdb)] {
					foreach cmd $Opt(cmdb) {
						task name=/distribution/command role=$role ! {
							params ! {
								param name=CMDS_TO_RUN value=$cmd -
							}
						}
					}
				}
				# kernelinstall
				if {$KVARIANT in "debug" && ![info exist Opt(nvr)]} {
					set reg $DISTRO
					if [regexp {^RHEL-[0-9]\.[0-9]$} $reg] {
						regsub RHEL-([0-9]+\.[0-9]+) $reg RHEL-./\1 reg
					}
					set res [exec vershow {^kernel-[2-4]+[-.0-9]+\.} $reg]
					regsub {.*(kernel-[2-4]+[-.0-9]+\.[^.]+).*} $res {\1} Opt(nvr)
				}
				if {[info exist Opt(nvr)] && $Opt(nvr) != "" && $Opt(nvr) != "{}"} {
					set NVR $Opt(nvr)
					task name=/distribution/kernelinstall role=$role ! {
						params ! {
							param name=KERNELARGNAME value=kernel -
							param name=KERNELARGVERSION value=[regsub ^kernel- $NVR {}] -
							param name=KERNELARGVARIANT value=$KVARIANT -
						}
					}
				}
				# command after kernelinstall
				if [info exist Opt(cmd)] {
					foreach cmd $Opt(cmd) {
						task name=/distribution/command role=$role ! {
							params ! { param name=CMDS_TO_RUN value=$cmd - }
						}
					}
				}
				# pkg install
				if [info exist Opt(install)] {
					foreach pkg $Opt(install) {
						task name=/distribution/pkginstall role=$role ! {
							params ! { param name=PKGARGNAME value=$pkg - }
						}
					}
				}
				# --kcov task
				if [info exist Opt(kcov)] {
					task name=/distribution/pkginstall role=$role ! {
						params ! { param name=PKGARGNAME value=lcov - }
					}
					task name=/kernel/kcov/prepare role=$role ! {
						params ! {
							param name=MODE value=KA -
							param name=KDIR {value=fs, net/sunrpc} -
						}
					}
					task name=/kernel/kcov/start role=$role ! {
						params -
					}
				}
				# --kdump task
				if [info exist Opt(kdump)] {
					lassign [regsub (.*?):/(.*$) $Opt(kdump) {\1 {\2}}] NFSSERVER VMCOREPATH
					if { [ string length $NFSSERVER ] == 0 } {
						set NFSSERVER "ibm-x3250m4-02.rhts.eng.pek2.redhat.com"
					}
					if { [ string length $VMCOREPATH ] == 0 } {
						set VMCOREPATH "home/kdump/vmcore/"
					}
					task name=/kernel/kdump/setup-nfsdump role=$role ! {
						params ! {
							param name=NFSSERVER value=${NFSSERVER} -
							param name=VMCOREPATH value=/${VMCOREPATH} -
							param name=NO_COMPRESS value=1
						}
					}
				}

				# --leap-second
				if [info exist Opt(leap-second)] {
					task name=/kernel/general/time/leap-second/ins_leap_sec role=$role ! {
						params -
					}
				}

				# task list
				foreach task ${TaskList} {
					set name [lindex $task 0]
					set arglist [lrange $task 1 end]
					task name=$name role=$role ! {
						if {$restraint == "yes"} {
							set head kernel
							if [regexp {^/CoreOS/} $name] {
								set head [lindex [split $name /] 2]
							}
							if [regexp "/$head/?\\??" $restraint_git] {
								set head {}
							}
							doTag fetch url=$restraint_git/$head#[string map "/CoreOS {} /$head/ {}" $name] -
						}
						params ! {
							foreach arg $arglist {
								lassign [regsub {(^[^=]*)=(.*)} $arg {\1 {\2}}] pname pvalue
								# use "mh-" prefix to set different value for multihost
								if [regexp {^mh-} $pname] {
									set pname [string range $pname 3 end]
									set pvalue_list [split $pvalue ,]
									param name=$pname value=[lindex $pvalue_list $R] -
								} else {
									param name=$pname value=$pvalue -
								}
							}
						}
					}
				}
				# --kcov task
				if [info exist Opt(kcov)] {
					task name=/kernel/kcov/end role=$role ! {
						params -
					}
					task name=/kernel/kcov/finalize role=$role ! {
						params -
						#params ! {
							#param name=NFS_SHARE value=$NFS_SHARE -
							#param name=TASKNAME value=$TASKNAME -
						#}
					}
				}
				# --reserve-if-fail
				if [info exist Opt(reserve-if-fail)] {
					set ReserveTime {356400}
					if {[string length $Opt(reserve-if-fail)] > 0} {
						set ReserveTime $Opt(reserve-if-fail)
					}

					set time {}
					task name=/distribution/reservesys role=$role ! {
						params ! {
							param name=RESERVE_IF_FAIL value=1 -
							param name=ESERVETIME value=${ReserveTime} -
						}

					}
				}
			}
			set R [ expr $R + 1 ]
		}
	}
}
puts ""

