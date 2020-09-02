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

has achievements => (
  is => 'lazy',
  builder => sub { _build_data($_[0], 'achieve') },
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

has combo_table => (
  is => 'lazy',
  builder => sub { _combo_table_init($_[0]) },
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

  if(exists $vc->{$category} || $category eq 'achieve') {
    return $vc->{$category};
  } elsif(exists $gc->{'nh_variants'}{'nh'}{$category}) {
    return $gc->{'nh_variants'}{'nh'}{$category};
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
# This function takes conduct and achieve bitmap and returns either number
# of conducts or list of conduct abbreviations, depending on context.  The
# list of conduct abbreviations is ordered according to ordering in
# "nh_conduct_ord".
#
# Conducts are signalled through 'conduct' and (oddly) 'achieve' xlogfile
# fields. Also, there is a patch that causes the game write out number
# of times the player has written Elbereth, which can be used to deduce
# the state of "elberethless" conduct.
#===========================================================================

sub conduct
{
  my (
    $self,
    $conduct_bitfield,    # 1. 'conduct' field from xlogfile
    $elbereths,           # 2. 'elbereths' field from xlogfile
    $achieve_bitfield,    # 3. 'achieve' field from xlogfile
  ) = @_;

  my @conducts;

  #--- get reverse code-to-value mapping for conducts

  my %con_to_val = reverse %{$self->conducts()};
  my %ach_to_val = reverse %{$self->achievements() // {}};

  #--- get ordered list of conducts

  for my $c ($self->config()->list_conducts_ordered()) {
    if($c eq 'elbe' && defined $elbereths && !$elbereths) {
      push(@conducts, $c);
      last;
    }

    if(exists $con_to_val{$c} && $conduct_bitfield) {
      if ($con_to_val{$c} =~ /^0x/) {
        $con_to_val{$c} = hex $con_to_val{$c};
      }
      if($conduct_bitfield & $con_to_val{$c}) {
        push(@conducts, $c);
      }
    }

    elsif(exists $ach_to_val{$c} && $achieve_bitfield) {
      if ($ach_to_val{$c} =~ /^0x/) {
        $ach_to_val{$c} = hex $ach_to_val{$c};
      }
      if($achieve_bitfield & $ach_to_val{$c}) {
        push(@conducts, $c);
      }
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


#===========================================================================
# Function to initialize table of role-race-alignment combos (gender is left
# out). It returns hashref with two keys:
# - table -- contains three dimensional array reference
# - idx -- contains hash ref with {role}{race}{align} index to above table;
#          the index is understood as triplet of indexes into the 3-d array
#===========================================================================

sub _combo_table_init
{
  #--- arguments

  my $self = shift;

  #--- do nothing for variants with undefined rules/enums

  return undef if
    !$self->combo_defined()
    || !( $self->rules() || $self->enum() );

  #--- init the structure

  my @table;
  my %idx;
  my %ct = ( 'table' => \@table, 'idx' => \%idx );

  #--- init the table
  # value of -1 marks unavailable combo
  # we could also do a pass to mark invalid columns -2,
  # i.e. if every role for a given race/align combo is -1
  # then we set those to -2 - will also need a way to
  # save the disallowed race/align combos for table header
  # purposes. another option would be to rework/make an
  # additional combo_valid subroutine that just checks
  # whether a race/align combination is permitted
  # this could end up being difficult if there are variants
  # that allow certain roles to override typical race/alignment
  # rules...
  my $i = 0;
  foreach my $role (@{$self->roles()}) {
    my @ary_races;
    my $j = 0;
    foreach my $race (@{$self->races()}) {
      my @ary_aligns;
      my $k = 0;
      foreach my $align (@{$self->alignments()}) {
        my $val = 0;
        foreach my $gender (@{$self->genders()}) {
          $val ||= $self->combo_valid($role, $race, $gender, $align);
        }
        $val = $val ? undef : -1;
        push(@ary_aligns, $val);
        $idx{$role}{$race}{$align} = [ $i, $j, $k ];
        $k++;
      }
      push(@ary_races, \@ary_aligns);
      $j++
    }
    push(@table, \@ary_races);
    $i++;
  }

  return \%ct;
}



#===========================================================================
# Update value in a combotable cell specified by (role, race, alignment).
#===========================================================================

sub combo_table_cell
{
  my $self = shift;
  my ($role, $race, $align, $val) = @_;
  my ($i, $j, $k);
  my $ct = $self->combo_table();

  return undef if !defined $ct;

  ($role, $race, $align) = map { lc } ($role, $race, $align);

  if(!exists $ct->{'idx'}{$role}{$race}{$align}) {
    warn sprintf('Invalid character combination %s-%s-%s', $role, $race, $align);
    return;
  }
  ($i, $j, $k) = @{$ct->{'idx'}{$role}{$race}{$align}};

  if($val) {
    $ct->{'table'}[$i][$j][$k] = $val;
  }
  return $ct->{'table'}[$i][$j][$k];
}



#===========================================================================
# Combotable iterator. The iterator function is called for every cell of the
# table and gets value/role/race/alignment as its four arguments.
#===========================================================================

sub combo_table_iterate
{
  my $self = shift;
  my $iterator = shift;
  my $cnt = 0;

  my $i = 0;
  foreach my $role (@{$self->roles()}) {
    my $j = 0;
    foreach my $race (@{$self->races()}) {
      my $k = 0;
      foreach my $align (@{$self->alignments()}) {
        my $val = $self->combo_table_cell($role, $race, $align);
        $cnt++ if &$iterator($val, $role, $race, $align);
      }
      $j++
    }
    $i++;
  }
  return $cnt;
}



#===========================================================================
# This is a workaround for dNetHack peculiar combo descriptor mangling.
# This mangling was later fixed (combo now shows what one would expect),
# so this is only done for the two extant winning games with mangled combo.
# WARNING: The 'Elf' in role field can actually mean many other roles apart
# from Noble and there is no way to know which one it really is. The non-
# winning game will remain messed up.
#===========================================================================

sub dnethack_map
{
  my $self = shift;
  my ($role, $race) = @_;

  if($role eq 'Dna') {
    return ('Kni', 'Dwa');
  }

  if($role eq 'Elf' && $race eq 'Elf') {
    return ('Nob', 'Elf');
  }

  if($role eq 'Hdr' && $race eq 'Dro') {
    return ('Rog', 'Dro');
  }

  return ($role, $race);
}


1;
