#!/usr/bin/env perl

#===========================================================================
# This class is an interface for NetHack::Config that implements
# variant-specific queries.
#===========================================================================

package NetHack::Variant;
use NetHack::Config;

use Carp;
use Moo;

has variant => (
  is => 'ro',
  required => 1,
);

has config => (
  is => 'ro',
);

has conducts => (
  is => 'lazy',
  builder => sub { _build_data($_[0], 'conduct') },
);

has roles => (
  is => 'lazy',
  builder => sub { _build_data($_[0], 'roles') },
);

has races => (
  is => 'lazy',
  builder => sub { _build_data($_[0], 'races') },
);

has genders => (
  is => 'lazy',
  builder => sub { _build_data($_[0], 'genders') },
);

has alignments => (
  is => 'lazy',
  builder => sub { _build_data($_[0], 'aligns') },
);


#===========================================================================
# Builder function for the above attributes.
#===========================================================================

sub _build_data
{
  my $self = shift;
  my $category = shift;
  my $vc = $self->_def();
  my $gc = $self->config()->config();

  if(exists $vc->{$category}) {
    return $vc->{$category};
  } elsif(exists $gc->{'nh_variants'}{'nh'}{$category}) {
    return $gc->{'nh_variants'}{'nh'}{$category}
  } else {
    croak sprintf(
      'No definition for "%s" in "%s"',
      $category,
      $self->variant()
    );
  }
}


#===========================================================================
# Return variant configuration.
#===========================================================================

sub _def
{
  my $self = shift;
  my $c = $self->config()->config();

  return $c->{'nh_variants'}{ $self->variant() };
}


#===========================================================================
# This function takes conduct bitmap and returns either number of conducts
# or list of conduct abbreviations, depending on context. The list of
# conduct abbreviations is ordered according to ordering in
# "nh_conduct_ord".
#
# There's one complication: in some variants elberethless conduct is
# signalled by the 'elbereths' xlogfile field.
#===========================================================================

sub conduct
{
  my (
    $self,
    $conduct_bitfield,    # 1. 'conduct' field from xlogfile
    $elbereths,           # 2. 'elbereths' field from xlogfile
  ) = @_;

  my @conducts;

  #--- get reverse code-to-value mapping for conducts

  my %con_to_val = reverse %{$self->conducts()};

  #--- get ordered list of conducts

  for my $c ($self->config()->list_conducts_ordered()) {
    if($c eq 'elbe' && defined $elbereths && !$elbereths) {
      push(@conducts, $c);
      last;
    }
    my $v = $con_to_val{$c};
    next if !$v;
    if($conduct_bitfield & $v) {
      push(@conducts, $c);
    }
  }

  #--- return depending on context

  return wantarray ? @conducts : scalar(@conducts);
}


#===========================================================================
# Function returns true if all of the available roles/races/genders/aligns
# are explicitly defined in the configuration for given variant (ie. no
# fallback to the canonic lists defined for vanilla NetHack).
#===========================================================================

sub combo_defined
{
  my $self = shift;

  return
    !exists $self->_def()->{'roles'}
    || !exists $self->_def()->{'races'}
    || !exists $self->_def()->{'genders'}
    || !exists $self->_def()->{'aligns'}
    ?
    0 : 1;
}


1;
