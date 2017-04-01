#!/bin/sh
# Jianhong Yin <yin-jianhong@163.com>
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh "$0" ${1+"$@"}

lappend auto_path .
lappend auto_path /usr/local/lib
package require getOpt 3.0
namespace import ::getOpt::*

# global var
array set Opt {}
array set InvalidOpt {}
set NotOptions [list]
set ForwardOpt {}
set OptionList {
	"*Options:" {}

	"  *Options group description1:" {
		{f file listf}	{arg y	help {#Specify a test list file}}
		cc	{arg m	help {#Notify additional e-mail address on job completion}}
	}

	"\n  *Options group description2:" {
		kcov	{arg n	help {#insert kcov task for do the kernel test coverage check}}
		kdump	{arg o	help {#insert kdump task for get core dump file if panic happen}}
	}

	"\n  *Options group description3:" {
		debugi	{hide y}
		debugii	{hide y}
		{h help H}	{}
		repo	{forward y arg m	help {Configure repo at <URL> in the kickstart for installation}}
		recipe	{forward y arg n	help {Just generate recipeSet node, internal use for runtest -merge}}
	}
}

# getUsage test
puts "Usage: $argv0 \[options\]"
getUsage $OptionList

# _parse_ argument
getOptions $OptionList $::argv Opt InvalidOpt NotOptions ForwardOpt
parray Opt
parray InvalidOpt
puts "NotOptions: $NotOptions"
puts "ForwardOpt: $ForwardOpt"
