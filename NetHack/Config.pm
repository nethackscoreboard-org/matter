#!/usr/bin/env perl

#===========================================================================
# This module encapsulates NetHack configuration and creates interfaces to
# access the configuration data. Note, that variant-specific info uses the
# NetHack::Variant class (which still uses the ::Config class as the data
# source).
#===========================================================================

package NetHack::Config;
use NetHack::Variant;

use Moo;
use JSON;

has config_file => (
  is       => 'ro',
  required => 1,
);

has config => (
  is       => 'lazy',
  builder  => '_build_config',
);


#===========================================================================
# Parsing the configuration file on creation of a new object.
#===========================================================================

sub _build_config
{
  my ($self) = @_;
  
  if(-r $self->config_file()) {
    local $/;
    my $js = new JSON->relaxed(1);
    open(my $fh, '<', $self->config_file());
    my $def_json = <$fh>;
    my $cfg = $js->decode($def_json) or die 'Cannot parse NetHack.pm configuration';
    return $cfg;
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


#===========================================================================
# Get list of conducts ordering
#===========================================================================

sub list_conducts_ordered
{
  my $self = shift;
  return @{$self->config()->{'nh_conduct_ord'}};
}


#===========================================================================
# Return instance of the NetHack::Variant object with the 'config' attribute
# set to reference self (ie. this NetHack::Config object)
#===========================================================================

sub variant
{
  my $self = shift;
  my $variant = shift;

  return new NetHack::Variant(config => $self, variant => $variant);
}


1;
