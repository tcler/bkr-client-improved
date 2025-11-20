########################################################################
#
#  runtestlib -- APIs for get test attr, generate WhiteBoard info etc
#
# (C) 2014 Jianhong Yin <jiyin@redhat.com>
#
# $Revision: 1.0 $, $Date: 2017/07/17 10:57:22 $
########################################################################
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh "$0" ${1+"$@"}

namespace eval ::runtestlib {
	namespace export dbroot genWhiteboard expandDistro hostUsed runtestConf autorunConf
}

set runtestConf /etc/bkr-client-improved/bkr-runtest.conf
set runtestConfPrivate $::env(HOME)/.bkr-client-improved/bkr-runtest.conf

set autorunConf /etc/bkr-client-improved/bkr-autorun.conf
set autorunConfPrivate $::env(HOME)/.bkr-client-improved/bkr-autorun.conf

proc ::runtestlib::dbroot {args} {
	set homedir $::env(HOME)

	set user [lindex $args 0]
	if {$user != ""} {
		set homedir [exec sh -c "getent passwd $user|awk -F: '{print \$6}'"]
	}
	return $homedir/.testrundb
}

proc ::conf2dict {confStr} {
	set res {}
	set P 0;  #stat in ""
	set S 0;  #stat in ''

	set confStr [string trim $confStr]
	if {[string length $confStr] == 0} { return "" }

	if {[string index $confStr end] != ","} {
		append confStr ","
	}
	set Len [string length $confStr]
	for {set i 0} {$i < $Len} {incr i} {
		set n [string index $confStr $i]
		set p [string index $confStr [expr $i -1]]

		if {$n == " " && $p in {" " ":"} && $P==0 && $S==0} {
			continue
		}

		if {$n in ":" && $P == 0 && $S == 0} {
			append res " \{"
		} elseif {$n in "," && $P == 0 && $S == 0} {
			set res [string trimright $res]
			append res "\}"
		} else {
			if {$S == 0 && $n in {\"} && $p ni {\\}} {
				set P [expr ($P+1)%2]
			}
			if {$P == 0 && $n in {'}} {
				set S [expr ($S+1)%2]
				set n "\{"
				if {$S == 0} { set n "\}" }
			}
			append res $n
		}
	}
	return [string trim $res]
}

proc ::runtestlib::genWhiteboard {distro testkey testList format {comment ""}} {
	proc pop {varname} {
		upvar 1 $varname var
		set var [lassign $var head]
		return $head
	}

	# Find common directory path
	proc common_prefix {dirs {separator "/"}} {
		set parts [split [pop dirs] $separator]
		while {[llength $dirs]} {
			set r {}
			foreach cmp $parts elt [split [pop dirs] $separator] {
				if {$cmp ne $elt} break
				lappend r $cmp
			}
			set parts $r
		}
		return [join $parts $separator]
	}

	lassign $testkey issched igset
	regexp {(pkg|component)(=|: )?([^ ,{}]+)} $testList _match _key _op component
	if {![info exist component] || $component == ""} {set component ?}

	# Gen gset string
	set gset [lindex $testkey 1]
	set options [lrange $testkey 2 end]

	# Gen topo descrition
	set topoDesc S
	if [regexp -- {topo=[^0-9 ]*([0-9]+)[^0-9 ]+([0-9]+)} "$gset $options"] {
		lassign [regsub {.*topo=[^0-9]*([0-9]+)[^0-9]+([0-9]+).*} "$gset $options" {\1 \2}] servNum clntNum
		set topoDesc M.$servNum.$clntNum
	}
	if {$component in {merged}} { set topoDesc X }

	# Get task number
	set tnum [llength $testList]

	# Get common directory path as test summary prefix
	set tnameList {}
	set testSummPrefix {}
	foreach t $testList {
		set tname [lindex $t 0]
		if {$tname == "-"} {set tname [lindex $t 1]}
		append tnameList " $tname"
	}
	set testSummPrefix [common_prefix $tnameList]

	# handle each test tail name for test summary
	# and aggregate them like bash brace expansion
	set tcnt 0
	set tccnt 0
	set tcurr {}
	set tprev {}
	set testSumm {}
	set testSummMaxLen 80
	set maxlen [expr $testSummMaxLen/($tnum>5?5:$tnum)]
	foreach t $testList {
		set tname [lindex $t 0]
		set ttail [string range $tname [string length $testSummPrefix] end]
		set ttail [string trimleft $ttail '/']

		if {$ttail == ""} {
			set ttail [file tail $testSummPrefix]
			set testSummPrefix [file dir $testSummPrefix]
		}

		if {[string length $ttail] > $maxlen} {
			set ttail [string range $ttail 0 $maxlen].
		}

		set tcurr $ttail
		if {$tcurr == $tprev} {
			set tccnt [expr $tccnt + 1]
			if {$tccnt == 1} {
				append testSumm /.
			}
			if {$tccnt <= 5} {
				append testSumm .
			}
			continue
		}

		set tcnt [expr $tcnt + 1]
		if {$tcnt > 1} {
			append testSumm ,
		}

		append testSumm $tcurr
		if {[string length $testSumm] > $testSummMaxLen} {
			append testSumm ,...
			break
		}

		set tprev $tcurr
		set tccnt 0
	}
	if {$tcnt > 1} {
		set testSumm \{$testSumm
		append testSumm \}
	}

	if {$comment != ""} {
		set comment "\[$comment\]:"
	}

	set time [clock format [clock seconds] -format %Y%m%d~%H:%M]
	set WB $format
	if {$WB == ""} {set WB {[%T] [%P@%D %H:%N] %C%S/%s %G}}
	regsub -all "%T" $WB "$time" WB
	regsub -all "%P" $WB "$component" WB
	regsub -all "%D" $WB "$distro" WB
	regsub -all "%H" $WB "$topoDesc" WB
	regsub -all "%N" $WB "$tnum" WB
	regsub -all "%C" $WB "$comment" WB
	regsub -all "%S" $WB "$testSummPrefix" WB
	regsub -all "%s" $WB "$testSumm" WB
	regsub -all "%G" $WB "$gset" WB

	return $WB
}

proc ::runtestlib::expandDistro {distroStr {bootc "no"}} {
	if {$distroStr == ""} {
		return ""
	}

	#If distroStr is short format
	lappend distrol {*}[split $distroStr ", "]
	set distronl {}
	if {$bootc == "yes"} {
		foreach d $distrol {
			if [regexp -- {^[0-9.]+n?$} $d] {
				puts stderr "{debug} expanding DISTRO pattern: $d ..."
				set d [string map {n {}} $d]
				set get_tag_cmd "skopeo list-tags --retry-times 16 docker://images.paas.redhat.com/bootc/rhel-bootc | jq -r .Tags\[\] | grep RHEL-$d | tail -1 || :"
				set bootcTo [exec bash -c $get_tag_cmd]
				set get_compose_cmd "skopeo inspect --retry-times 16 docker://images.paas.redhat.com/bootc/rhel-bootc:$bootcTo | jq -r '.Labels\[\"redhat.compose-id\"\]' || :"
				set d [exec bash -c $get_compose_cmd]
				if {$d == ""} {
					puts stderr "{warn} expanding DISTRO pattern: $d fail"
					set d {followImageTag}
				}
			}
			lappend distronl ${d}
		}
	} else {
		foreach d $distrol {
			if [regexp -- {^[0-9]+n$} $d] {
				puts stderr "{debug} expanding DISTRO pattern: $d ..."
				set d [string map {n {}} $d]
				if {$d eq "7"} {
					set pat {RHEL-7.9-updates-[0-9]{8}\.[0-9]+}
				} else {
					set pat "RHEL-$d.\[0-9]+(\.\[0-9]+)?-\[0-9]{8}\.\[0-9]+"
				}
				set d [exec bash -c "distro-compose -dlist|grep -E '$pat'|head -1; :"]
			} elseif [regexp -- {^(alt-)?[0-9]} $d] { set d [exec bash -c "getLatestRHEL $d; :"] }
			lappend distronl ${d}
		}
	}
	set distroStr [join $distronl ,]
	return $distroStr
}

proc ::runtestlib::hostUsed {args} {
	array set hostused_ {}
	array set hostused {}
	set result {}
	set user [lindex $args 0]
	set dbfile [dbroot $user]/testrun.db
	if ![file exist $dbfile] {
		return "invalid user OR no robot instance"
	}
	sqlite3 db_ $dbfile

	#Get running test list
	array set runingTest {}
	db_ eval {
	    select
	        trun.distro_rgset as rgset,
	        trun.res as res,
	        trun.jobid as jobid,
	        ti.test as test
	    from testrun trun
	    join testinfo ti on
	        (trun.testStat = 'running' or trun.res LIKE '%New%') and ti.testid = trun.testid
	} {
		set arch x86_64
		if [regexp -- {.*-arch=([^ ]+)} "$test $rgset"] {
			regexp -- {.*-arch=([^ ]+)} "$test $rgset" _arch arch
		}
		set hostused_($arch\ $jobid) [llength $res]
	}
	foreach {arch_job N} [array get hostused_] {
		incr hostused([lindex $arch_job 0]) $N
	}

	foreach {arch N} [array get hostused] {
		append result "$arch:$N "
	}
	return [string trim $result]
}
