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

has name => (
  is => 'lazy',
  builder => sub { _build_data($_[0], 'name') },
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

has rules => (
  is => 'lazy',
  builder => sub { _build_validation($_[0], 'rules') },
);

has enum => (
  is => 'lazy',
  builder => sub { _build_validation($_[0], 'enum') },
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
# Code for intializing the 'rules'/'enum' atributes which have different
# fallback logic.
#===========================================================================

sub _build_validation
{
  my $self = shift;
  my $category = shift;
  my $other = $category eq 'rules' ? 'enum' : 'rules';
  my $vc = $self->_def();
  my $gc = $self->config()->config();

  if(exists $vc->{$category}) {
    return $vc->{$category};
  } elsif(exists $vc->{$other}) {
    return undef;
  } elsif(exists $gc->{'nh_variants'}{'nh'}{$category}) {
    return $gc->{'nh_variants'}{'nh'}{$category};
  } else {
    return undef;
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
    !$self->roles()
    || !$self->races()
    || !$self->genders()
    || !$self->alignments()
    ?
    0 : 1;
}


#===========================================================================
# Function returns whether given player character combination is a valid
# one. Validation is performed according to a ruleset from nethack_def.json
# configuration file.
#
# If for given variant there is no ruleset, the one from 'nh' (vanilla
# Nethack) is used as default.
#
# The ruleset is array of rules; each rule is in turn an array in one of
# following forms:
#
#    |<--- trigger rule(s) ------------>|<--- enforce rules ----->|
#
#    1. [ match,                           rule1, rule2, ..., ruleN ]
#    2. [ [ match1, match2, ..., matchN ], rule1, rule2, ..., ruleN ]
#
# When "trigger rule(s)" match the function arguments, the enforce
# rules must be satisfied, otherwise the whole validation will
# immediately fail, returning NOT VALID result. To validate a combo,
# all rules must be processed without failing.
#
# Both trigger and enforce rules are four letter strings. The first letter is
# special and determines player character category
#
#    $ role, % race, # alignment, ! gender
#
# These categories correspond to the function arguments.
#
# Role, race, alignment, gender is then a standard three letter code as
# defined in role.c, such as $arc, %hum, #law, !fem.
#===========================================================================

sub combo_valid_by_rules
{
  #--- arguments (in lowercase)

  my $self = shift;

  my (
    $role,
    $race,
    $gender,
    $alignment
  ) = map { lc } @_;

  #--- if not rules exist, return undef

  return undef if !defined $self->rules();

  #--- iterate over all rules (start)

  foreach my $rule (@{$self->rules()}) {

  #--- trigger rules

    my $trigger_state = 0;
    my $trigger_set = ref($rule->[0]) ? $rule->[0] : [ $rule->[0] ];
    for my $trigger_rule (@$trigger_set) {
      $trigger_rule =~ /(.)(...)/;
      my ($category, $value) = ($1, $2);
      if(
        $category eq '$' && $value eq $role
        || $category eq '%' && $value eq $race
        || $category eq '#' && $value eq $alignment
        || $category eq '!' && $value eq $gender
      ) {
        $trigger_state++;
      }
    }
    next if $trigger_state < scalar(@$trigger_set);

  #--- enforce rules

    my %cat_val = ('$', $role, '%', $race, '#', $alignment, '!', $gender);
    my @enforce_rules = @{$rule}[1 .. (scalar(@$rule)-1) ];
    for my $cat (keys %cat_val) {
      my $catq = quotemeta($cat);
      my $val = $cat_val{$cat};
      if(
        grep(/^$catq/, @enforce_rules)
        && !grep(/^$catq($val)$/, @enforce_rules)
      ) {
        return 0;
      }
    }

  #--- iterate over all rules (end)

  }

  #--- finish successfully

  return 1;

}


#===========================================================================
# This is alternative to combo_valid_by_rules() that decides combo's
# validity by searching list of all possible combos.
#===========================================================================

sub combo_valid_by_enum
{
  #--- arguments (in lowercase)

  my $self = shift;

  my (
    $role,
    $race,
    $gender,
    $alignment
  ) = map { lc } @_;

  #--- return false if no list def exists for given variant

  return undef if !defined $self->enum();

  #--- search the list

  if(
    grep {
      lc($_->[0]) eq $role
      && lc($_->[1]) eq $race
      && lc($_->[2]) eq $gender
      && lc($_->[3]) eq $alignment
    } @{$self->enum()}
  ) {
    return 1;
  } else {
    return 0;
  }
}


#===========================================================================
# Combine the two combo validation functions into one.
#===========================================================================

sub combo_valid
{
  my $self = shift;

  #--- if the given variant does not all of the allowable character
  #--- categories defined, then we do not perform combo validity check at
  #--- all and just return true

  return 1 if !$self->combo_defined();

  #--- combine the two validation methods

  return $self->combo_valid_by_enum(@_) || $self->combo_valid_by_rules(@_);
}


1;
