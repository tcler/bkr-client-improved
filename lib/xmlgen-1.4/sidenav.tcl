#!/bin/sh
#\
exec tclsh $0 -test "$@"
########################################################################
#
# An attempt for a navigation bar on the left. Layout done with a
# table. 
#
# (C) 2002 Harald Kirsch
# $Revision: 1.3 $, $Date: 2002/08/07 17:33:08 $
########################################################################

namespace eval ::htmlgen::sidenav {

namespace export sidenav

## default values for configurable attributes of sidenav
set sidenavDefaultAttrs {
    nav.valign top
    txt.valign top
    nav.width 100
    main.border 0
    main.cellspacing 0
    main.cellpadding 2
    main.width 100%
    curColor red
    navByUrl 0
}


########################################################################
## Create an indented table row with some colored content
## Indentation is faked with a full table having some empty columns in
## front.
##
proc onerow {text level} {
  for {set i 0} {$i<$level} {incr i} {
    put "&nbsp;&nbsp;&nbsp;"
    set text [small $text]
  }
  put $text [br] \n
  return
}


########################################################################
## Find unique node name $current within $tree and return the full
## path. 
proc digTree {current tree} {
  foreach {node text subtree} $tree {
    if {"$node"=="$current"} {return $current}
    if {[llength $subtree]<3} continue
    set rest [digTree $current $subtree]
    if {""=="$rest"} continue
    return [concat [list $node] $rest]
  }
  return ""
}


########################################################################
## Render a navigation tree along a path given by $current leading
## into the tree. Every level of the tree is created as a block. The
## blocks are separated by horizontal rules. On every level, the
## selected element is printed in the color given by attribute
## curColor.
##
## We descend into subtrees only if $current really selects one of
## them. If $current contains nonsense, only the top level of the tree
## is rendered with nothing selected. The verified part of $current is
## returned in the end.
proc renderTree {ID url current tree} {
  upvar A A
  set level 0
  set path {}
  set newpath {}

  if {$A(navByUrl)} {
    set current [digTree $current $tree]
  }
  ## A tree of length 1 indicates an empty tree. Nonempty trees have
  ## a multiple of 2 elements.
  while {[llength $tree]>1} {
    if {[llength $tree]%3!=0} {
      set l [split $tree \n]
      append msg "navigation tree must have length of 3*n:\n" \
	  \"[join [lrange $l 0 3] \n]
      if {[llength $l]>4} { append msg "\n  ...\"" }
      return -code error $msg	  
    }
    set head [lindex $current 0]
    if {$level>0} { put [hr] }

    set tmp $tree
    set tree .
    foreach {node text subtree} $tmp {
      if {$A(navByUrl)} {
	set href $url/$node
      } else {
	set href $url?[::htmlgen::cgiset $ID [concat $path [list $node]]]
      }
      if {"$node"!="$head"} {
	onerow [a href=$href $text] $level
	continue
      }
      ## we hit a selected node, so we can extend the verified path
      ## and prepare to descent into the subtree
      set newpath [concat $path [list $node]]
      set tree $subtree
      if {[llength $current]==1} {
	## exactly the selected node, so no link
	onerow [font color=$A(curColor) $text] $level
      } else {
	onerow [a href=$href [font color=$A(curColor) $text]] $level
      }
    }
    set path $newpath
    set current [lrange $current 1 end]
    incr level
  }
  return $path
}


proc attrget {aryname prefix} {
  upvar $aryname A
  set res {}
  set l [string length ${prefix}.]
  foreach x [array names A ${prefix}.*] {
    set suf [string range $x $l end]
    if {-1!=[string first . $suf]} continue
    lappend res $suf=$A($x)
  }
  return $res
}


proc sidenav {pathvar url tree args} {
  upvar $pathvar path
  variable sidenavDefaultAttrs
  array set A $sidenavDefaultAttrs

  foreach {opentag control body closetag} \
      [::xmlgen::makeTagAndBody {} $args A] break

  eval table [attrget A main] ! {{
    tr ! {
      eval td [attrget A nav] ! {{
	set path [renderTree $pathvar $url $path $tree]
      }}
      eval td [attrget A txt] ! {{
	uplevel 1 "::xmlgen::runbody {} {$control} {$body} {}"	
      }}
    }
  }}
}
########################################################################

set testScript {
## BEGIN TEST SCRIPT
    set auto_path [concat . /home/kir/work /usr/local/lib $auto_path]
    foreach {i} {tcllib htmlgen ncgi} { package require $i }
    namespace import -force htmlgen::*
    namespace import -force ::htmlgen::sidenav::*
    
    # Start of HTML Content
    ::ncgi::parse
    
    set navTree {
      home Home .
      tcl Tcl {
        kit TclKit . 
        w83 Wish83 {
          story Story .
          doc Documentation .
        }
        fw FreeWrap .
      }
      perl Perl {
        bad {Perl No Fun} .
        doc {NO DOCS} .
      }
    }
    
    html ! {
      body ! {
        set url [ncgi::urlStub]
        set path [ncgi::value path {tcl}]
        sidenav path $url $navTree nav.bgcolor=\#dddd55 txt.bgcolor=\#dddd00 ! {
          h2 - Some Information about [join $path /]
          p + {
    	The selected path is 
          }
          blockquote - [code . path="$path"]. 
          p + { 
    	Depending on that,
    	we could have different content introduced here in several
    	ways, e.g.
          }
          ul ! {
    	li - use a [code switch on \$path]
    	li - access a content array like [code \$Content(\$path)]
    	li - source a file depending on \$path
          }
          table ! tr ! td height=1000 - "&nbsp;"
        }
      }
    }
    # Finish with regular puts to end with newline
    puts {}
    
### END TEST SCRIPT
}

### END NAMESPACE
}

# Execute test script if -test option specified
if { [string match "-test" [lindex $argv 0]] } {
    ::xmlgen::buffer html $::htmlgen::sidenav::testScript
    set fh [open test.html w]; puts $fh $html; close $fh
}