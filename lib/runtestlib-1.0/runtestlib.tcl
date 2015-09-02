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
	namespace export dbroot testinfo genWhiteboard expandDistro hostUsed conf_file
}

set conf_file /etc/bkr-client-improved/bkr-autorun.conf
set conf_file_private $::env(HOME)/.bkr-client-improved/bkr-autorun.conf
if [file exists $conf_file_private] { set conf_file $conf_file_private }

proc ::runtestlib::dbroot {} {
	source $::conf_file

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
			if ![regsub {.*pkg=([^ ]*).*} $tattr {\1} _pkg] { set _pkg pkg=? }
			if ![regsub {.*(ssched=..).*} $tattr {\1} _ssched] { set _ssched ssched=no }
			if ![regsub {.*(topo=[^ ]*).*} $tattr {\1} _topo] { set _topo topo=single? }
			set key "$_pkg $_ssched $_topo"
			lappend key $gset
			set ret $key
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

proc ::runtestlib::genWhiteboard {distro testkey testList} {
	lassign $testkey pkg ssched topo gset
	set gset [string trimleft $gset]
	set tnum [llength $testList]

	set topoDesc S
	if {$pkg in {merged}} { set topoDesc X }
	if [string match topo=multi* $topo] {
		lassign [regsub {.*?([0-9]+).([0-9]+).*} $topo {\1 \2}] servNum clntNum
		set topoDesc M.$servNum.$clntNum
		set gset [concat --servers=$servNum --clients=$clntNum $gset]
	} else {}

	set testSumm {}
	set testSummMaxLen 30
	foreach t $testList {
		set tname [lindex $t 0]
		set tail [file tail $tname]
		set maxlen [expr $testSummMaxLen/($tnum>5?5:$tnum)]
		if {[string length $tail] > $maxlen} {
			set tail [string range $tail 0 $maxlen].
		}
		append testSumm ,$tail
		if {[string length $testSumm] > $testSummMaxLen} {
			set testSumm [string range $testSumm 0 $testSummMaxLen]...
			break
		}
	}
	if {[string index $testSumm 0] == ","} {
		set testSumm [string range $testSumm 1 end]
	}

	set WB "\[[clock format [clock seconds] -format %Y%m%d~%H:%M]\] $pkg $topoDesc\\$tnum/$testSumm@$distro $gset"

	return [list $WB $gset]
}

proc ::runtestlib::expandDistro {distroStr} {
	if {$distroStr == ""} {
		return ""
	}

	#If distroStr is short format
	lappend distrol {*}[split $distroStr ", "]
	set distronl {}
	foreach d $distrol {
		if [regexp -- {^[0-9]} $d] { set d [exec getLatestRHEL {*}[regsub {^([0-9]+)(.*)} $d {\2 \1}]] }
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
	        trun.res as res,
	        trun.jobid as jobid,
	        ti.test as test
	    from testrun trun
	    join testinfo ti on
	        (trun.testStat = 'running' or trun.res LIKE '%New%') and ti.testid = trun.testid
	} {
		set arch [testinfo arch $test]
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
