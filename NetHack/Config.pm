#!/usr/bin/env perl

#===========================================================================
# This module contains NetHack configuration related functions.
#===========================================================================

package NetHack::Config;

use Moo;
with 'MooX::Singleton';
use JSON;

has config_file => (is => 'ro', required => 1);
has config      => (is => 'rw');


#===========================================================================
# Parsing the configuration file on creation of a new object.
#===========================================================================

sub BUILD {
  my ($self) = @_;
  
  if(-r $self->config_file()) {
    local $/;
    my $js = new JSON->relaxed(1);
    open(my $fh, '<', $self->config_file());
    my $def_json = <$fh>;
    my $cfg = $js->decode($def_json) or die 'Cannot parse NetHack.pm configuration';
    $self->config($cfg);
  } else {
    die 'Cannot read config file ' . $self->config_file();
  }
}


#===========================================================================
# Return ordered list of variant shortcodes
#===========================================================================

sub variants
{
  my $self = shift;
  return @{$self->config()->{'nh_variants_ord'}};
}


#===========================================================================
# Return variant shortcode to variant fullname hash. The returned hash is
# a newly created copy of the original.
#===========================================================================

sub variant_names
{
  my $self = shift;
  my $h = { %{$self->config()->{'nh_variants_def'}} };
  return $h;
}


1;
