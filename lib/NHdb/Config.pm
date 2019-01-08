#!/usr/bin/env perl

#=============================================================================
# Module for NHdb specific configuration and configuration-dependent stuff.
#=============================================================================

package NHdb::Config;

use Moo;
with 'MooX::Singleton';

use JSON;
use FindBin qw($Bin);
use Path::Tiny;


#=============================================================================
#=== ATTRIBUTES ==============================================================
#=============================================================================

has config => (
  is       => 'lazy',
  builder  => '_build_config',
);


#=============================================================================
#=== METHODS =================================================================
#=============================================================================

#=============================================================================
# Configuration loading
#=============================================================================

sub _build_config
{
  my ($self) = @_;
  my $js = JSON->new()->relaxed(1);

  #--- read the main config file

  my $def_json = path($Bin, 'cfg/nhdb_def.json')->slurp_raw();
  my $nhdb_def = $js->decode($def_json);

  #--- read the file with db passwords (if defined)

  if(exists $nhdb_def->{'auth'}) {
    $def_json = path($Bin, 'cfg', $nhdb_def->{'auth'})->slurp_raw();
    $nhdb_def->{'auth'} = $js->decode($def_json);
  }

  return $nhdb_def;
}


#=============================================================================
# Return whether supplied player name is on the black list
# (feeder.reject_name configuration entry).
#=============================================================================

sub reject_name
{
  my ($self, $name) = @_;
  my $c = $self->config();

  return
    (grep { $name eq $_ } @{$c->{'feeder'}{'reject_name'}})
    ? 1 : 0;
}


#=============================================================================
# Return list of regular xlogfile fields (feeder.regular_fields)
#=============================================================================

sub regular_fields
{
  my ($self) = @_;
  my $c = $self->config();

  if(
    exists $c->{'feeder'}{'regular_fields'}
    && ref $c->{'feeder'}{'regular_fields'}
  ) {
    return @{$c->{'feeder'}{'regular_fields'}}
  } else {
    return ();
  }
}


#=============================================================================
# Check if supplied fields satisfy the feeder.required_fields requirements.
#=============================================================================

sub require_fields
{
  my ($self, @fields) = @_;
  my $c = $self->config();

  foreach my $required_field (@{$c->{'feeder'}{'require_fields'}}) {
    if(!grep { $_ eq $required_field } @fields) { return undef; }
  }
  return 1;
}


#=============================================================================
# Return whether supplied variant is in the 'firsttoascend' list (when
# 'variant' argument is supplied), or just list of the first to ascend
# variants.
#=============================================================================

sub first_to_ascend
{
  my ($self, $variant) = @_;
  my $c = $self->config();

  if($variant) {
    return
      (grep { $variant eq $_ } @{$c->{'firsttoascend'}})
      ? 1 : 0;
  } else {
    return @{$c->{'firsttoascend'}};
  }
}


#=============================================================================

1;
