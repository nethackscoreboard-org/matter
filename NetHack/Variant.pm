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
  builder => '_build_conducts',
);


#===========================================================================
# Initialize conducts to point to the "conducts" section of variant's
# config (with a fallback to vanilla conducts).
#===========================================================================

sub _build_conducts
{
  my $self = shift;
  my $vc = $self->_def();
  my $gc = $self->config()->config();

  if(exists $vc->{'conduct'}) {
    return $vc->{'conduct'};
  } elsif(exists $gc->{'nh_variants'}{'nh'}{'conduct'}){
    return $gc->{'nh_variants'}{'nh'}{'conduct'}
  } else {
    croak 'No conduct bitmap defined for ' . $self->variant();
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


1;
