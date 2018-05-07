#!/usr/bin/env perl

#===========================================================================
# This module contains NetHack related function.
#===========================================================================

package NetHack2;

use Moo;
use JSON;

#===========================================================================
# Internal data
#===========================================================================

my $cfg;


#===========================================================================
# Parsing the configuration file on creation of a new object.
#===========================================================================

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;

  my $config_file = $args[0];
  
  if($config_file && -r $config_file) {
    local $/;
    my $js = new JSON->relaxed(1);
    open(my $fh, '<', $config_file);
    my $def_json = <$fh>;
    $cfg = $js->decode($def_json) or die 'Cannot parse NetHack.pm configuration';
  }

  @args = ('config_file', $config_file);
  
  return $class->$orig(@args);
};


#===========================================================================
# Return ordered list of variant shortcodes
#
# OLD NAME: nh_variants(FALSE)
#===========================================================================

sub variants
{
  return @{$cfg->{'nh_variants_ord'}};
}


#===========================================================================
# Return variant shortcode to variant fullname hash. The returned hash is
# a newly created copy of the original.
#
# OLD NAME: nh_variants(TRUE)
#===========================================================================

sub variant_names
{
  my $h = { %{$cfg->{'nh_variants_def'}} };
  return $h;
}


1;
