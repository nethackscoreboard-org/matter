#!/usr/bin/perl

#===========================================================================
# NetHack database project library
#===========================================================================

package NHdb;
require Exporter;
use NetHack;
use JSON;
use POSIX qw(strftime);
use integer;
use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(
  %field_names
  format_number
  format_duration
  html_span
  html_ahref
  html_head
  html_close
  html_table_head
  format_row
  url_substitute
);


#--- field names mappings

our %field_names = (
  'n'           => '&nbsp;',
  'name'        => 'name',
  'character'   => 'character',
  'points'      => 'points',
  'turns'       => 'turns',
  'duration'    => 'duration',
  'hp'          => 'HP',
  'time'        => 'time',
  'conducts'    => 'conducts',
  'conducts_fw' => 'conducts',            # conducts "full width" (with trailing spaces)
  'death'       => 'death reason',
  'played'      => 'played',
  'ascended'    => 'won',
  'wonpct'      => '%',
  'score'       => 'score',
  'maxconducts' => 'cond',
  'maxlvl'      => 'maxlvl',
  'scumcnt'     => 'scum',
  'tscore'      => 'score',
  'ncond'       => 'conducts',
  'name_nl'     => 'name',                # 'no link' name
  'strlen'      => 'len',
  'strgames'    => 'streak games',
  'dlvl'        => 'dlvl',
  'role'        => 'role',
  'version'     => 'ver',
  'server'      => 'srv',
  'variant'     => 'var'
);

my @field_numeric = qw(
  n points turns duration hp wonpct ascended played tscore maxlvl
  scumcnt ncond dlvl maxconducts
);


#=== this holds all defs

our $nhdb_def;


#===========================================================================
#=== BEGIN SECTION =========================================================
#===========================================================================

BEGIN
{
  local $/;
  my $fh;
  open($fh, '<', 'nhdb_def.json') or die;
  my $def_json = <$fh>;
  $nhdb_def = decode_json($def_json);
}


#===========================================================================
# Formats decadic number into format with orders grouped by threes and
# divide by commas.
#===========================================================================

sub format_number
{
  my $n = shift;
  my $x = '';
  my $f;

  while(length($n) > 0) {
    if(length($n) <= 3) { $x = $n . $f . $x; last; }
    $x = substr($n, length($n)-3, 3) . $f . $x;
    $n = substr($n, 0, length($n)-3);
    $f = ',';
  }
  return $x;
}


#===========================================================================
#===========================================================================

sub format_duration
{
  my $realtime = shift;
  my ($d, $h, $m, $s) = (0,0,0,0);
  my $duration;
  
  $d = $realtime / 86400;
  $realtime %= 86400;
  
  $h = $realtime / 3600;
  $realtime %= 3600;
  
  $m = $realtime / 60;
  $realtime %= 60;
  
  $s = $realtime;
  
  $duration = sprintf("%s:%02s:%02s", $h, $m, $s);
  if($d) {
    $duration = sprintf("%s, %s:%02s:%02s", $d, $h, $m, $s);
  }

  return $duration;  
}


#===============================================================================
#===============================================================================

sub char_combo
{
  my $k = shift;
  
  return sprintf(
    "%s-%s-%s-%s", 
    $k->{role}, 
    $k->{race}, 
    $k->{gender}, 
    $k->{align}
  );
}


#===============================================================================
#===============================================================================

sub html_ahref
{
  my ($url, $txt) = @_;

  return sprintf(qq{<a href="%s">%s</a>}, $url, $txt);
}

sub html_span
{
  my ($txt, $class) = @_;

  return sprintf(
    qq{<span class="%s">%s</span>},
    $class,
    $txt
  );
}


#===============================================================================
#===============================================================================

sub html_head
{
  my $fh = shift;    # 1. file handle
  my $title = shift; # 2. title
  my $css = shift;   # 3. css file (optional)
  
  #---
  
  if(!$css) { $css = 'default.css'; }

  #--- '_player' special-cased
  printf($fh "<!doctype html>\n\n");
  printf($fh "<html>\n\n");
  printf($fh "<head>\n");
  printf($fh qq{  <link rel="stylesheet" type="text/css" href="$css">\n});
  printf($fh "  <title>$title</title>\n");
  printf($fh "</head>\n\n");

  printf($fh qq{<body class="page_back">\n\n});
  printf($fh qq{<div class="page">\n\n});
  printf($fh qq{<div class="page_content">\n});
  
  printf($fh "<h1>%s</h1>\n\n", $title);
}


#===============================================================================
#===============================================================================

sub html_close
{
  my $fh = shift;    # 1. file handle

  printf($fh "</div>\n");
  printf($fh "</div>\n");
  printf($fh qq{<div class="updatetime">Last updated: %s</div>\n}, strftime("%c", localtime()));
  printf($fh "</body>\n\n");
  printf($fh "</html>\n");
}


#===============================================================================
# This function produces one row of table heading on supplied file handle.
# The list of field has optional special encoding as <field>%<n> where n is
# number of columns the field should be taking (using COLSPAN attribute). If
# n=0, then the column is completely ommited.
#===============================================================================

sub html_table_head
{
  my ($fh, $fields) = @_;

  print $fh "<tr>";
  for my $f (@$fields) {
    my ($fi, $cs) = split('%', $f);
    next if (defined($cs) && $cs == 0);
    if($cs > 1) {
      printf $fh q{<th colspan="%d">%s</th>}, $cs, $field_names{$fi};
    } else {
      printf $fh q{<th>%s</th>}, $field_names{$fi};
    }
    
  }
  print $fh "</tr>";
}


#===============================================================================
# Function to perform substitutions on an URL (or any string). The supported
# substitutions are:
#
# %u - username
# %U - first letter of username
# %s - start time
#===============================================================================

sub url_substitute
{
  my $strg = shift;
  my $data = shift;

  my $r_username = $data->{'name'};
  my $r_uinitial = substr($data->{'name'}, 0, 1);
  my $r_starttime = $data->{'starttime_raw'};
  my $r_endtime = $data->{'endtime_raw'};

  $strg =~ s/%u/$r_username/g;
  $strg =~ s/%U/$r_uinitial/g;
  $strg =~ s/%s/$r_starttime/g;
  $strg =~ s/%e/$r_endtime/g;

  return $strg;
}


#===============================================================================
# This function formats field 'key' from row in 'data' into HTML represented
# output. Note, that field does not necessarily correspond to field in database
# table, some of the fields are composites.
#===============================================================================

sub format_field
{
  my (
    $key,          # req | field name     | scal
    $data,         # req | data           | href
    $server,       # req | server info    | href
    $class_td,     # opt | TD class(es)   | scal aref
    $class_span,   # opt | SPAN class(es) | scal aref
    $href          # opt | url            | scal
  ) = @_;
  my $result;
  
  #--- make td/span a array ref if it is not
  
  if($class_td && !ref($class_td)) {
    $class_td = [ $class_td ];
  }
  if($class_span && !ref($class_span)) {
    $class_span = [ $class_span ]; 
  }
  
  #--- set 'numeric' class for fields listed in @field_numeric

  if(grep { $_ eq $key } @field_numeric) {
    push(@$class_td, 'numeric');
  }
  
  #--- open TD
  
  my $html_td = '<td>';
  if($class_td) {
    $html_td = sprintf('<td class="%s">', join(' ', @$class_td));
  }
  $result = $html_td;
    
  #--- open SPAN
  
  my $html_span;
  if($class_span) {
    $html_span = sprintf('<span class="%s">', join(' ', @$class_span));
    $result .= $html_span if $html_span;
  } 
  
  #--- open A HREF
  
  my $html_a;
  if($href) {
    $html_a = sprintf('<a href="%s">', $href);
    $result .= html_$a;
  }

  #--- field formatting

  SWITCH: for ($key) {

    /^n$/ && do {
      $result .= $data->{'n'};
      last SWITCH;
    };

    /^character$/ && do {
      $result .= char_combo($data);
      last SWITCH;
    };

    /^turns$/ && do {
      $result .= format_number($data->{$key});
      last SWITCH;
    };

    /^points$/ && do {
      my $pts = format_number($data->{$key});
      if($server->{'dumpurl'}) {
        my $url = $server->{'dumpurl'};
        $url = url_substitute($url, $data);
        $pts = html_ahref($url, $pts);
      }
      $result .= $pts;
      last SWITCH;
    };

    /^tscore$/ && do {
      $result .= format_number($data->{$key});
      last SWITCH;
    };

    /^duration$/ && do {
      if(defined($data->{'realtime'})) {
        $result .= format_duration($data->{'realtime'});
      }
      last SWITCH;
    };

    /^hp$/ && do {
      $result .= sprintf('%d/%d', $data->{'hp'}, $data->{'maxhp'});
      last SWITCH;
    };

    /^time$/ && do {
    #  $result .= format_time($data->{'endtime'});
      $result .= $data->{'endtime'}; #'-unimplemented-';
      last SWITCH;
    };

    /^ncond$/ && do {
      $result .= nh_conduct($data->{'conduct'});
      last SWITCH;
    };

    /^conducts$/ && do {
      $result .= join(' ', nh_conduct($data->{'conduct'}));
      last SWITCH;
    };

    /^conducts_fw$/ && do {
      my @c = conducts($data->{'conduct'}, undef, 1);
      $result .= sprintf('%d</td><td><tt>%s</tt>', @c);
      last SWITCH;
    };

    /^ncond$/ && do {
      my @c = conducts($data->{'conduct'}, undef, 1);
      $result .= sprintf('%d', $c[0]);
      last SWITCH;
    };

    /^name$/ && do {
      $result .= $data->{$key};
      last SWITCH;
    };

    /^dlvl$/ && do {
      $result .= sprintf(qq{%d/%d}, $data->{deathlev}, $data->{maxlvl});
      last SWITCH;
    };

    /^death$/ && do {
      my @c = nh_conduct($data->{'conduct'});
      if($data->{'death'} eq 'ascended') {
        if(scalar(@c) == 0) {
          $result .= 'ascended with all conducts broken';
        } else {
          $result .= sprintf(
            qq{ascended with %d conduct%s intact (%s)},
            scalar(@c), (scalar(@c) == 1 ? '' : 's'), join(' ', @c)
          );
        }
      } else {
        $result .= $data->{'death'}
      }
      last SWITCH;
    };

#    when ('strgames') {
#      my $f;
#      for my $g ( @{$data->{'strgames'}}) {
#        $result .= ' ' if $f;
#        $result .= sprintf '<span class="combo">&nbsp;%s&nbsp;</span>', char_combo($games[$g]);
#        $f = 1;
#      }
#    }

    /^strlen$/ && do {
      if($data->{'open'}) {
        $result .= sprintf('<span class="streak-open">%d</span>', $data->{$key});
      } else {
        $result .= sprintf('%d', $data->{$key});
      }
      last SWITCH;
    };

    $result .= sprintf('%s', $data->{$key});
  } 
  
  #--- close A HREF, SPAN and TD
  
  if($html_a) { $result .= '</a>'; }
  if($html_span) { $result .= '</span>'; }
  $result .= '</td>';

  #--- finish
  
  return $result;
}


#===============================================================================
#===============================================================================

sub format_row
{
  my $row = shift;
  my $fields = shift; 
  my $server = shift;
  my $class_tr = shift; # (optional)
  my $result;
  
  #--- open
  
  if($class_tr && !ref($class_tr)) { $class_tr = [ $class_tr ]; }
  if($class_tr) {
    $result = sprintf('<tr class="%s">', join(' ', @$class_tr));
  } else {
    $result = '<tr>';
  }
  
  #--- body
  
  for my $f (@$fields) {
    my ($fi) = split('%', $f);
    my @span_class;
    #if(exists $row->{'_hilite'} && grep {$_ eq $fi} @{$row->{'_hilite'}}) {
    #  $span_class[0] = 'hilite';
    #}
    if($row->{'ascended'}) { $span_class[0] = 'hilite'; }
    $result .= format_field(
      $fi,
      $row,
      $server,
      undef,
      \@span_class,
      undef,
      undef
    );
  }
  
  #--- close 
  
  $result .= "</tr>\n";
  return $result;
}



1;

