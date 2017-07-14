########################################################################
#
#  runtestlib -- APIs for get test attr, generate WhiteBoard info etc
#
# (C) 2014 Jianhong Yin <jiyin@redhat.com>
#
# $Revision: 1.0 $, $Date: 2014/12/15 10:57:22 $
########################################################################
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh "$0" ${1+"$@"}

namespace eval ::runtestlib {
	namespace export dbroot testinfo genGset genWhiteboard expandDistro hostUsed runtestConf autorunConf
}

set runtestConf /etc/bkr-client-improved/bkr-runtest.conf
set runtestConfPrivate $::env(HOME)/.bkr-client-improved/bkr-runtest.conf
if [file exists $runtestConfPrivate] { set runtestConf $runtestConfPrivate }

set autorunConf /etc/bkr-client-improved/bkr-autorun.conf
set autorunConfPrivate $::env(HOME)/.bkr-client-improved/bkr-autorun.conf
if [file exists $autorunConfPrivate] { set autorunConf $autorunConfPrivate }

proc ::runtestlib::dbroot {} {
	source $::autorunConf

	return "$DB_ROOT"
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

proc ::runtestlib::testinfo {subcmd testobj} {
	set tattr {}
	set param {}
	set gset {}

	set tname [lindex $testobj 0]
	set testdesc "[regsub -- {^ *[^ ]* *} $testobj {}]"
	set dictStr [::conf2dict "$testdesc"]

	foreach {k v} $dictStr {
		if {$k == "Attr"} {
			set tattr [concat $tattr $v]
		} elseif {$k == "Param"} {
			set param [concat $param $v]
		} elseif {$k == "GlobalSetup"} {
			set gset [concat $gset $v]
		}
	}

	set ret ""
	switch -exact -- $subcmd {
		"recipekey" {
			if ![regsub {.*(ssched=..).*} $tattr {\1} _ssched] { set _ssched ssched=no }
			set key "$_ssched"
			lappend key $gset
			set ret $key
		}
		"attr" {
			set ret $tattr
		}
		"param" {
			set ret $param
		}
		"arch" -
		"gset" {
			if {$subcmd == "arch"} {
				set ret x86_64
				if [regexp -- {-arch=([^ ]+)} $gset] {
					set ret [regsub {.*-arch=([_0-9a-zA-Z]+).*} $gset {\1}]
				}
			} else {
				set ret $gset
			}
		}
		"pkg" {
			regsub  {.*pkg=([^ ]*).*} $tattr  {\1}  pkg
			set ret $pkg
		}
		"md5sum" {
			set ret "$tname $param $gset"
		}
		"tier" {
			regsub  {.* level=[Tt]ier([0-9]).*} $tattr {\1} tier
			if {$tier == ""} {set tier 1}
			set ret $tier
		}
	}

	return $ret
}

proc ::runtestlib::genGset {testkey} {
	lassign $testkey ssched gset
	set gset [string trimleft $gset]
	return $gset
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
	regexp {pkg(=|: )?([^ ,]+)} $testList _ignore _op pkg 
	if {![info exist pkg] || $pkg == ""} {set pkg ?}

	# Gen gset string
	set gset [genGset $testkey]

	# Get task number
	set tnum [llength $testList]

	# Gen topo descrition
	set topoDesc S
	if [string match *topo=* $gset] {
		lassign [regsub {.*topo=[^0-9]*([0-9]+)[^0-9]+([0-9]+).*} $gset {\1 \2}] servNum clntNum
		set topoDesc M.$servNum.$clntNum
	}
	if {$pkg in {merged}} { set topoDesc X }

	# Get common directory path as test summary prefix
	set tnameList {}
	set testSummPrefix {}
	foreach t $testList {
		set tname [lindex $t 0]
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
	regsub -all "%P" $WB "$pkg" WB
	regsub -all "%D" $WB "$distro" WB
	regsub -all "%H" $WB "$topoDesc" WB
	regsub -all "%N" $WB "$tnum" WB
	regsub -all "%C" $WB "$comment" WB
	regsub -all "%S" $WB "$testSummPrefix" WB
	regsub -all "%s" $WB "$testSumm" WB
	regsub -all "%G" $WB "$gset" WB

	return $WB
}

proc ::runtestlib::expandDistro {distroStr} {
	if {$distroStr == ""} {
		return ""
	}

	#If distroStr is short format
	lappend distrol {*}[split $distroStr ", "]
	set distronl {}
	foreach d $distrol {
		if [regexp -- {^[0-9]} $d] { set d [exec getLatestRHEL $d] }
		lappend distronl ${d}
	}
	set distroStr [join $distronl ,]
	return $distroStr
}

proc ::runtestlib::hostUsed {} {
	array set hostused_ {}
	array set hostused {}
	set result {}
	cd [dbroot]
	sqlite3 db_ testrun.db

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
		set arch [testinfo arch $test]
		if [regexp -- {-arch=([^ \"']+)} $rgset] {
			regexp -- {-arch=([^ \"']+)} $rgset _arch arch
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
