########################################################################
#
#  getOpt -- similar as getopt_long_only(3)
#
# (C) 2017 Jianhong Yin <yin-jianhong@163.com>
#
# $Revision: 1.0 $, $Date: 2017/02/24 10:57:22 $
########################################################################
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh "$0" ${1+"$@"}

namespace eval ::getOpt {
	namespace export getOptions getUsage
}

proc ::getOpt::getOptObj {optList optName} {
	foreach {optNameList optAttr} $optList {
		if {$optName in $optNameList} {
			return [list [lindex $optNameList 0] $optAttr]
		}
	}
	return ""
}

proc ::getOpt::argparse {optionList argvVar optVar optArgVar} {
	upvar $argvVar  argv
	upvar $optVar optName
	upvar $optArgVar optArg

	set result -2
	set optName ""
	set optArg ""

	if {[llength $argv] == 0} {
		return 0
	}

	set rarg [lindex $argv 0]
	if {$rarg in {-}} {
		set optArg $rarg
		set argv [lrange $argv 1 end]
		return 2
	}
	if {$rarg in {--}} {
		set optArg [lrange $argv 0 end]
		set argv [list]
		return 2
	}

	set argv [lrange $argv 1 end]
	switch -glob -- $rarg {
		"-*" -
		"--*" {
			set opttype long
			set optName [string range $rarg 1 end]
			if [string equal [string range $optName 0 0] "-"] {
				set optName [string range $rarg 2 end]
			} else {
				set opttype longonly
			}

			set idx [string first "=" $optName 1]
			if {$idx != -1} {
				set _val [string range $optName [expr $idx+1] end]
				set optName [string range $optName 0 [expr $idx-1]]
			}

			lassign [getOptObj $optionList $optName] optFind optAttr
			if {$optFind != ""} {
				set optName $optFind
				set result 1
				set argtype n
				if [dict exists $optAttr arg] {
					set argtype [dict get $optAttr arg]
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
			} elseif {$opttype in {longonly}} {
				if [info exists _val] { append optName =$_val }
				# expand short args
				set insertArgv [list]
				while {[string length $optName]!=0} {
					set x [string range $optName 0 0]
					set optName [string range $optName 1 end]

					if {$x in {= - { } \\ \' \"}} break

					lassign [getOptObj $optionList $x] x optAttr
					if {$x == ""} {
						lappend insertArgv  --$x
						continue
					}

					if {[dict exist $optionList $x link]} {
						set x [dict get $optionList $x link]
						lassign [getOptObj $optionList $x] x optAttr
						if {$x == ""} {
							lappend insertArgv  --$x
							continue
						}
					}

					set xtype n
					if [dict exists $optAttr arg] {
						set xtype [dict get $optAttr arg]
					}
					switch -exact -- $xtype {
						"n" { lappend insertArgv  --$x }
						"o" {
							lappend insertArgv  --$x=$optName
							break
						}
						"y" -
						"m" {
							if {[string length $optName]==0} {
								lappend insertArgv  --$x
							} else {
								lappend insertArgv  --$x=$optName
							}
							break
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
			set optArg $rarg
			set result 2
		}
	}

	return $result
}

proc ::getOpt::getOptions {optLists argv validOptionVar invalidOptionVar notOptionVar {forwardOptionVar ""}} {
	upvar $validOptionVar validOption
	upvar $invalidOptionVar invalidOption
	upvar $notOptionVar notOption
	upvar $forwardOptionVar forwardOption

	set optList "[concat {*}[dict values $optLists]]"
	set notOption [list]
	set opt ""
	set optarg ""
	set nargv $argv
	set forwardOpts ""
	#set argc [llength $nargv]

	while {[set err [argparse $optList nargv opt optarg]]} {
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
			lassign [getOptObj $optList $opt] _optFind optAttr
			if [dict exists $optAttr arg] {
				set argtype [dict get $optAttr arg]
			}

			set forward {}
			if [dict exists $optList $opt forward] {
				set forward y
			}

			if {$forward == "y"} {
				switch -exact -- $argtype {
					"n" {lappend forwardOption "--$opt"}
					default {lappend forwardOption "--$opt=$optarg"}
				}
				continue
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

proc ::getOpt::genOptdesc {optNameList} {
	# print options as GNU style:
	# -o, --long-option	<abstract>
	set shortOpt {}
	set longOpt {}

	foreach k $optNameList {
		if {[string length $k] == 1} {
			lappend shortOpt -$k
		} else {
			lappend longOpt --$k
		}
	}
	set optdesc [join "$shortOpt $longOpt" ", "]
}

proc ::getOpt::getUsage {optLists} {

	foreach {group optDict} $optLists {

	#ignore hide options
	foreach key [dict keys $optDict] {
		if [dict exist $optDict $key hide] {
			dict unset optDict $key
		}
	}

	puts "$group"

	#generate usage list
	foreach opt [dict keys $optDict] {
		set pad 26
		set argdesc ""
		set optdesc [genOptdesc $opt]

		set argtype n
		if [dict exists $optDict $opt arg] {
			set argtype [dict get $optDict $opt arg]
		}
		switch -exact $argtype {
			"o" {set argdesc {[arg]}; set flag(o) yes}
			"y" {set argdesc {<arg>}; set flag(y) yes}
			"m" {set argdesc {{arg}}; set flag(m) yes}
		}

		set opthelp {nil #no help found for this options}
		if [dict exists $optDict $opt help] {
			set opthelp [dict get $optDict $opt help]
		}

		set opt_length [string length "$optdesc $argdesc"]
		set help_length [string length "$opthelp"]

		if {$opt_length > $pad-4 && $help_length > 8} {
			puts [format "    %-${pad}s\n %${pad}s    %s" "$optdesc $argdesc" {} $opthelp]
		} else {
			puts [format "    %-${pad}s %s" "$optdesc $argdesc" $opthelp]
		}
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
