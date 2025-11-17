#!/usr/bin/expect
# The next line is executed by /bin/sh, but not tcl \
exec expect "$0" ${1+"$@"}

lappend ::auto_path $::env(HOME)/lib /usr/local/lib /usr/lib64 /usr/lib
package require sqlite3
package require runtestlib 1.1
package require json::write
namespace import ::runtestlib::*

trap {send_user "Got SIGPIPE"; exit} SIGPIPE

set user {}
set qpkg {}
set distroListTmp {}
set distroGsetList {}
if {$argc > 0} { set user [lindex $argv 0] }
if {$argc > 1} { set qpkg [lindex $argv 1] }
if {$argc > 2} { set distroListTmp [list {*}[lindex $argv 2]] }

if [info exists ::env(DEBUG)] {
	set logf "/tmp/wapp-trms-resjson.log"
	set chan [open $logf w]
	puts $chan "user: $user"
	puts $chan "qpkg: $qpkg"
	puts $chan "distroListTmp: $distroListTmp"
	close $chan
	file attributes $logf -permissions 00666
}

if {$user == ""} {
	return
}

set dbroot [dbroot $user]
if {![file isfile "$dbroot/testrun.db"]} {
	return
}

cd $dbroot
sqlite3 db testrun.db
db timeout 2000

#===============================================================================
# require view
array set RUN {}
set pkgQ "select DISTINCT ti.pkgName from testinfo ti"
set pkgList [db eval $pkgQ]

#json-begin
puts "{"

puts "\"components\": [::json::write array {*}[lmap item $pkgList {
    ::json::write string $item
}]],"

if {$qpkg == "" || $qpkg ni $pkgList} {
	set qpkg [lindex $pkgList 0]
}

proc build_date {distro} {
	regexp -- {-(\d{8})\.} $distro -> date
	if ![info exists date] {
		regexp -- {RHEL-(\d+\.\d+)} $distro -> date
	}
	return $date
}

foreach pkg $pkgList {
	set distroQ "
		select DISTINCT trun.distro_rgset
		from testrun trun
		join testinfo ti on
			trun.testid = ti.testid
		where ti.pkgName LIKE '$pkg' and trun.res != ''
	"
	set distroList [db eval $distroQ]
	if {$distroList == ""} { continue; }
	set distroListFedora [lsearch -all -inline $distroList Fedora-*]
	set distroListFamily [lsearch -all -inline $distroList family*]
	set distroList [concat $distroListFamily $distroListFedora [lsearch -regexp -all -inline $distroList RHEL\[0-9\]?-\[0-9\]*]]
	if ![info exists RUN($pkg)] {set RUN($pkg) {}}

	set distroList [lsort -decreasing -command {apply {{a b} {
	    set dateA [build_date $a]
	    set dateB [build_date $b]
	    return [package vcompare $dateA $dateB]
	}}} $distroList]
	lappend RUN($pkg) {*}$distroList
}

foreach v [lsort -decreasing $distroListTmp] {
	if {$v in $RUN($qpkg)} {lappend distroGsetList $v}
}

puts "\"test-run\": {"
set testruns {}
foreach {pkg runs} [array get RUN] {
        append testruns "\"${pkg}\": [::json::write array {*}[lmap item $RUN($pkg) {
            ::json::write string $item}]],"
}
puts [string range $testruns 0 end-1]
puts "},"

#default colum number if not specified
if {$distroGsetList == ""} {
	set distroGsetList $RUN($qpkg)
	set columNum [llength $distroGsetList]
	if {$columNum > 4} { set columNum 4 }
	set distroGsetList [lrange $distroGsetList 0 [expr $columNum-1]]
}

set SQL "select
    ti.testid,
    ti.test,\n"
set i 0; foreach distro_rgset [lrange $distroGsetList 0 end] {
    append SQL "    group_concat (case when trun.distro_rgset = '$distro_rgset' then trun.res||' '||trun.taskuri else NULL end) as res$i,\n"
    incr i
}
set i 0; foreach distro_rgset [lrange $distroGsetList 0 end] {
    append SQL "    group_concat (case when trun.distro_rgset = '$distro_rgset' then trun.resdetail else NULL end) as resd$i,\n"
    incr i
}
set SQL "[string range $SQL 0 end-2]
from testinfo ti
join testrun trun on
	trun.testid = ti.testid
where ti.pkgName LIKE '$qpkg'
group by ti.testid, ti.test
ORDER by ti.tier asc, ti.test asc"

#puts "SQL: $SQL"
puts "\"qresults\": {"
  puts "\"qruns\": [::json::write array {*}[lmap item $distroGsetList {
    ::json::write string $item}]],"
  puts "\"results\":"
    puts [exec sqlite3 -json testrun.db $SQL]
puts "}"

#json-end
puts "}"
