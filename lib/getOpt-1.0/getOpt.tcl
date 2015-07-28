########################################################################
#
#  getOpt -- similar as getopt_long_only(3)
#
# (C) 2014 Jianhong Yin <yin-jianhong@163.com>
#
# $Revision: 1.0 $, $Date: 2014/12/12 10:57:22 $
########################################################################
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh "$0" ${1+"$@"}

namespace eval ::getOpt {
	namespace export getOptions getUsage
}

proc ::getOpt::getOpt {optionList argvVar optVar optArgVar} {
	upvar $argvVar  argv
	upvar $optVar option
	upvar $optArgVar optArg

	set result -2
	set option ""
	set optArg ""

	if {[llength $argv] == 0} {
		return 0
	}

	set arg [lindex $argv 0]
	if {$arg in {-}} {
		set optArg $arg
		set argv [lrange $argv 1 end]
		return 2
	}
	if {$arg in {--}} {
		set optArg [lrange $argv 0 end]
		set argv [list]
		return 2
	}

	set argv [lrange $argv 1 end]
	switch -glob -- $arg {
		"-*" -
		"--*" {
			set opttype short
			set option [string range $arg 1 end]
			if [string equal [string range $option 0 0] "-"] {
				set option [string range $arg 2 end]
				set opttype long
			}

			set idx [string first "=" $option 1]
			if {$idx != -1} {
				set _val [string range $option [expr $idx+1] end]
				set option [string range $option 0 [expr $idx-1]]
			}

			if {[dict exist $optionList $option]} {
				if {[dict exist $optionList $option link]} {
					set option [dict get $optionList $option link]
				}
				set result 1
				set argtype n
				if [dict exists $optionList $option arg] {
					set argtype [dict get $optionList $option arg]
				}
				switch -exact -- $argtype {
					"o" {
						if [info exists _val] {
							set optArg $_val
						}
					}
					"y" -
					"m" {
						if [info exists _val] {
							set optArg $_val
						} elseif {[llength $argv] != 0 &&
							[lindex $argv 0] != "--"} {
							set optArg [lindex $argv 0]
							set argv [lrange $argv 1 end]
						} else {
							set result -1
						}
					}
				}
			} elseif {$opttype in {short}} {
				if [info exists _val] { append option =$_val }
				# expand short args
				set insertArgv [list]
				while {[string length $option]!=0} {
					set x [string range $option 0 0]
					if {$x in {= - { } \\ \' \"}} break
					set option [string range $option 1 end]
					if {![dict exist $optionList $x]} {
						lappend insertArgv  --$x
					} else {
						if {[dict exist $optionList $x link]} {
							set x [dict get $optionList $x link]
						}
						set xtype n
						if [dict exists $optionList $x arg] {
							set xtype [dict get $optionList $x arg]
						}
						switch -exact -- $xtype {
							"n" { lappend insertArgv  --$x }
							"o" {
								lappend insertArgv  --$x=$option
								break
							}
							"y" -
							"m" {
								if {[string length $option]==0} {
									lappend insertArgv  --$x
								} else {
									lappend insertArgv  --$x=$option
								}
								break
							}
						}
					}
				}
				set argv [concat $insertArgv $argv]
				return 3
			} else {
				set result -2
			}
		}
		default {
			set optArg $arg
			set result 2
		}
	}

	return $result
}

proc ::getOpt::getOptions {optList argv validOptionVar invalidOptionVar notOptionVar} {
	upvar $validOptionVar validOption
	upvar $invalidOptionVar invalidOption
	upvar $notOptionVar notOption

	set notOption [list]
	set opt ""
	set optarg ""
	set nargv $argv
	#set argc [llength $nargv]

	while {[set err [getOpt $optList nargv opt optarg]]} {
		if {$err == 3} {
			continue
		} elseif {$err == 2} {
			if {[lindex $optarg 0] == {--}} {
				set notOption [concat $notOption $optarg]
			} else {
				lappend notOption $optarg
			}
		} elseif {$err == 1} {
			#known options
			set argtype n
			if [dict exists $optList $opt arg] {
				set argtype [dict get $optList $opt arg]
			}
			switch -exact -- $argtype {
				"m" {lappend validOption($opt) $optarg}
				"n" {incr validOption($opt) 1}
				default {set validOption($opt) $optarg}
			}
		} elseif {$err == -1} {
			set invalidOption($opt) "option -$opt need argument"
		} elseif {$err == -2} {
			#unknown options
			set invalidOption($opt) "unkown options"
		} elseif {$err == 0} {
			#end of nargv
			break
		}
	}

	return 0
}

proc ::getOpt::getUsage {optList} {
	set optDict $optList

	#merge the options that means same(e.g. -h --help)
	foreach key [dict keys $optDict] {
		if [dict exist $optDict $key link] {
			set lnk [dict get $optDict $key link]
			if [dict exist $optDict $lnk] {
				dict set optDict $lnk [concat [dict get $optDict $lnk] "keys {$lnk,$key}"]
				dict unset optDict $key
			}
		} elseif [dict exist $optDict $key hide] {
			dict unset optDict $key
		}
	}

	puts "Options:"

	#generate usage list
	foreach key [dict keys $optDict] {
		set pad 26
		set keydesc $key
		set argdesc ""

		if [dict exist $optDict $key Dummy] {
			puts [dict get $optDict $key Dummy]
			continue
		}

		if [dict exist $optDict $key keys] {
			set keydesc [dict get $optDict $key keys]
		}

		set argtype n
		if [dict exists $optDict $key arg] {
			set argtype [dict get $optDict $key arg]
		}
		switch -exact $argtype {
			"o" {set argdesc {[arg]}; set flag(o) yes}
			"y" {set argdesc {<arg>}; set flag(y) yes}
			"m" {set argdesc {{arg}}; set flag(m) yes}
		}
		set opt_length [string length "-$keydesc $argdesc"]

		set keyhelp {nil #no help found for this options}
		if [dict exists $optDict $key help] {
			set keyhelp [dict get $optDict $key help]
		}
		set help_length [string length "-$keyhelp"]

		# print options as GNU style:
		# -o, --long-option	<abstract>
		set shortOpt {}
		set longOpt {}
		foreach k [split $keydesc ,] {
			if {[string length $k] == 1} {
				lappend shortOpt -$k
			} else {
				lappend longOpt --$k
			}
		}
		set keydesc [join "$shortOpt $longOpt" ", "]

		if {$opt_length > $pad-4 && $help_length > 8} {
			puts [format "    %-${pad}s\n %${pad}s    %s" "$keydesc $argdesc" {} $keyhelp]
		} else {
			puts [format "    %-${pad}s %s" "$keydesc $argdesc" $keyhelp]
		}
	}

	unset optDict

	puts "\nComments:"
	if [info exist flag] {
		puts {    *  [arg] means arg is optional, need use --opt=arg to specify an argument}
		puts {       <arg> means arg is required, and -f a -f b will get the latest 'b'}
		puts {       {arg} means arg is required, and -f a -f b will get a list 'a b'}

		puts {}
		puts {    *  if arg is required, '--opt arg' is same as '--opt=arg'}
		puts {}
	}
	puts {    *  '-opt' will be treated as:}
	puts {           '--opt'    if 'opt' is defined;}
	puts {           '-o -p -t' if 'opt' is undefined;}
	puts {           '-o -p=t'  if 'opt' is undefined and '-p' need an argument;}
	puts {}
}
