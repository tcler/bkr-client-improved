########################################################################
#
#  htmlgen -- generate HTML by writing Tcl code
# 
# (C) 2002 Harald Kirsch
#
# $Revision: 1.5 $, $Date: 2002/08/07 17:33:08 $
########################################################################

package require xmlgen

namespace eval ::htmlgen {

  namespace import -force \
      ::xmlgen::buffer ::xmlgen::channel ::xmlgen::put ::xmlgen::esc
  namespace export buffer channel put esc
  
  ## [html] catches errors of subordinate markup commands. If $debug
  ## is non-zero, $::errorInfo will be sent to the browser within a
  ## <pre>. If $debug is zero, only a general error message will be
  ## sent. 
  variable debug 1

  ## The following list is based on what I find in "HTML & XMTML" by
  ## Musciano and Kennedy (O'Reilly 2000), in particular the quick
  ## reference in the back of the book.

  # Skeletal Tags
  lappend htmltags body comment frameset frame noframes head html_raw

  # Header Tags
  lappend htmltags base basefont isindex link meta nextid style title
  
  # Hyperlinks
  lappend htmltags a

  # Text Markup Tags, physical tags
  lappend htmltags b big i s small strike sub sup tt u
  # oops, I forgot blink, what a pity

  # Text Markup Tags, content-based tags
  lappend htmltags abbr acronym cite code del dfn em ins \
      kbd samp strong var

  # Forms
  lappend htmltags form button fieldset input keygen \
      label legend select option optgroup textarea

  # Rules, Images, and Multimedia
  lappend htmltags bgsound img map area 
  # oops, I forgot marquee, what a pity

  # Formatted Lists
  lappend htmltags dir li del dd dt menu ol ul dl

  # Tables
  lappend htmltags table caption colgroup col tbody tfoot thead tr td th 

  # Executable Content
  lappend htmltags applet param embed noembed noscript object \
      param script server

  # Content Presentation and flow
  lappend htmltags address bdo blockquote br center div font \
      h1 h2 h3 h4 h5 h6 \
      hr iframe listing nobr p plaintext pre q span wbr xmp
  
  # Netscape-only Layout Tags
  #lappend htmltags layer multicol spacer

  foreach x $htmltags {
    ::xmlgen::declaretag $x
  }
  ## The split is necessary to iron out the \n in $htmltags
  eval namespace export [split $htmltags]

  namespace export html
  proc html {args} {
    foreach {o ctrl b c} [::xmlgen::makeTagAndBody html $args] break
    append o "\n<!-- generated with " \
	"Tcl's xmlgen-$::xmlgen::VERSION xmlgen] -->\n"
    set err \
	[catch {uplevel 1 [list ::xmlgen::runbody $o $ctrl $b $c]} r]
    if {!$err} { return $r}

    variable debug
    if {$debug} {
      put "<pre>[esc $::errorInfo]</pre>" \n
    } else {
      put "<pre>cgi script error encountered</pre>" \n
    }
  }

  ## copied straight from Don Libes' cgi.tcl/cgi_cgi_set
  namespace export cgiset
  proc cgiset {variable value} {
    regsub -all {%}  $value "%25" value
    regsub -all {&}  $value "%26" value
    regsub -all {\+} $value "%2b" value
    regsub -all { }  $value "+"   value
    regsub -all {=}  $value "%3d" value
    regsub -all \#  $value "%23" value
    regsub -all {/}  $value "%2f" value   ;# Added...
    return $variable=$value
  }
}

########################################################################
if { ![string match "[file tail $argv0]" [file tail [info script]] ] } return

## Test code
namespace import -force ::htmlgen::*


set CuteStyle {
  border-top:solid 2px red;
  border-right:solid 8px red;
}

buffer Page {
  head {
    title - A Song
    style type=text/css {+
      <!--
      var {color: \#44aa44;}
      code {color: \#555599;}
      -->
    }
  }
  body {
    h1 -  Ein Lied
    p {+
      Alle meine Entchen schwimmen auf dem [b See], schwimmen auf dem
      [i See], Köpfchen in das [i Wasser], Schwänzchen in die [em Höh'].
    }
    table width=80% border=1 align=center {
      caption - "Eine schöne Tabelle"
      tr {
	put [th style=$CuteStyle Eins] \n
	put [th Zwei] \n
      }
      tr {
	td valign=top - Hier boxt die Kuh.
	td align=right bgcolor=\#ff8888 {
	  ol  {
	    li - [font color=\#44aaff 13.55]
	    li - ach mist
	    li - hollerib [b boller]
	  }
	}
      }
      tr {
	td colspan=2 {
	  h5 align=right style=$CuteStyle {+
	    Ein Text aus [code man lappend].
	  }
	  p align=center {style=bgcolor=\#aaaaaa} {+
	    This  command  treats  the  variable given by 
	    [var varName] as a
	    list and appends each of the value arguments to that  list
	    as  a  separate element, with spaces between elements.  If
	    [var varName] doesn't exist, it is created as a list  with
	    elements 
	    given by the value arguments.  [code Lappend] is similar to 
	    [code append] except that the values are appended  as
	    list  elements 
	    rather than raw text.  This command provides a relatively
	    efficient way to build up large lists.   For  example,
	    [q [code lappend a \$b]] is much more efficient than
	  }
	  blockquote {
	    code - set a \[concat \$a \[list \$b\]\]
	  }
	  p - when \$a is long.
	}
      }
    }
  }
}

html {
  put $Page \n
}
