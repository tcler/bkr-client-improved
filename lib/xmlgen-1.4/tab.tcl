#!/bin/sh
#\
exec tclsh $0 -test "$@"
########################################################################
#
# simple notepad-tabs
#
# (C) 2002 Harald Kirsch
# $Revision: 1.2 $, $Date: 2002/06/10 03:17:42 $
########################################################################



namespace eval ::htmlgen::extra {
  namespace export tab

  ## default values for configurable attributes of tab
  array set tabDefaultAttrs {
    align center
    style {vertical-align: top;}
    width 100%
    selected-bg "\#ff5555"
    selected-fg black
    color black
    bgcolor "\#eeeeee"
    body-bg gold
    body-style {border: solid 1px; border-top:none}
  }

}

proc ::htmlgen::extra::tab {ID url current tabs args} {
  array set myAttr [array get ::htmlgen::extra::tabDefaultAttrs]

  foreach {opentag control body closetag} \
      [::xmlgen::makeTagAndBody {} $args myAttr] break

  append activeStyle "style=" \
      "padding-left: 15px;" \
      "padding-right: 15px;" \
      "border: outset 3px;" \
      "border-bottom: none;" \
      "border-left: solid 2px;" \
      "xborder-right: groove 8px;" \
      "xborder-top: solid 2px;" \
      "-moz-border-radius-topleft: 9px;" \
      "-moz-border-radius-topright: 9px;"
  append inactiveStyle "style="\
      "border-bottom: solid 1px;" \
      "padding-left: 15px;" \
      "padding-right: 15px;" \
      "-moz-border-radius-topleft: 9px;" \
      "-moz-border-radius-topright: 9px;"
 
  table width=$myAttr(width) cellspacing=0 \
      align=$myAttr(align) style=$myAttr(style) ! {
    tr ! {
      foreach pair $tabs {
	foreach {display tag} $pair break
	if {"$current"=="$tag"} {
	  td "bgcolor=$myAttr(selected-bg)" \
	      align=center $activeStyle - $display
	} else {
	  td "bgcolor=$myAttr(bgcolor)" align=center $inactiveStyle ! {
	    put [a "href=$url?$ID=$tag" $display]
	  }
	}
      }
      put [td {style=border-bottom: solid 1px;} width=100%  "&nbsp;"]
    }
    tr ! {
      td  style=$myAttr(body-style) bgcolor=$myAttr(body-bg) \
	  colspan=[expr {[llength $tabs]+1}] ! {
	    uplevel 1 "::xmlgen::runbody {} {$control} {$body} {}"
	  } 
    }
  }
}
########################################################################

## If sourced by another script, its time to return
if {"-test"!=[lindex $argv 0]} return
set argv [lrange $argv 1 end]



## TEST CODE
set auto_path [concat . /home/kir/work /usr/local/lib $auto_path]
package require tcllib
package require htmlgen
namespace import -force htmlgen::*
namespace import -force ::htmlgen::extra::*


putx "Content-Type: text/html\n"
::ncgi::parse


set l {
  {Eins eins}
  {Zwei zwei}
  {Drei drei}
  {Vier vier}
}


buffer Page {

  p - here is some text

  set ID [ncgi::value MegaTab eins]
 
  tab MegaTab [ncgi::urlStub] $ID $l \
      body-bg=gold selected-bg=gold width=60% ! {
    switch -- $ID {
      eins {
	h1 - eins
	p + { 
	  Now [big . I] [big [big [font color=red rebooted]]]. 
	  [big [big [big Jerry]]]
	  Pournelle. 
	}
      }
      zwei {b - zwei}
      drei {b - drei}
      vier {b - vier}
      default {
	putx [b Ooooops]
      }
    }
  }

  p + { 
    here[sup is] even more text and we go on and on.asdklf alskdjf lajs
    dflaksjdfla [acronym SDFK][sub asdlkfj] asldkf aldjf alsdkfj ladsf
    aldfj [strike aldjf]
    alsdjf aldfj alsdjf [dfn alsdfj] [strong alsfd] alsjfd alsdf alf
    alsdf alsdfj 
    alfd alsdfj alsdf aldjf alskd
  }
}

html ! {
  putx [title . a test tab]
  body ! {
    putx $Page
  }
}
