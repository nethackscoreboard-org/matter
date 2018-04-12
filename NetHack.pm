#!/usr/bin/env perl

#===========================================================================
# This module contains NetHack related function.
#===========================================================================

package NetHack;
require Exporter;
use integer;
use strict;
use Dir::Self;
use JSON;


our @ISA = qw(Exporter);
our @EXPORT = qw(
  nh_conduct
  nh_combo_defined
  nh_combo_valid
  nh_variants
  nh_char
  nh_combo_table_init
  nh_combo_table_cell
  nh_combo_table_iterate
  nh_dnethack_map
);


#=== this holds all defs

our $nh_def;


#===========================================================================
#=== BEGIN SECTION =========================================================
#===========================================================================

BEGIN
{
  local $/;
  my $js = new JSON->relaxed(1);
  open(my $fh, '<', __DIR__ . '/cfg/nethack_def.json');
  my $def_json = <$fh>;
  $nh_def = $js->decode($def_json);
}


#===========================================================================
#=== FUNCTIONS =============================================================
#===========================================================================


#===========================================================================
# This function takes conduct bitmap and returns either number of conducts
# or list of conduct abbreviations, depending on context. The list of
# conduct abbreviations is ordered according to ordering in
# "nh_conduct_ord".
#
# There's one complication: in some variants elberethless conduct is
# signalled by the 'elbereths' xlogfile field.
#===========================================================================

sub nh_conduct
{
  my (
    $conduct_bitfield,    # 1. 'conduct' field from xlogfile
    $elbereths,           # 2. 'elbereths' field from xlogfile
    $variant              # 3. variant code
  ) = @_;

  #--- other variables

  my @conducts;

  #--- choose mapping to be used

  my $bitmap_def = $nh_def->{'nh_conduct_bitmap_def'};
  if(exists($nh_def->{nh_variants}{$variant}{conduct})) {
    $bitmap_def = $nh_def->{nh_variants}{$variant}{conduct};
  }

  #--- get reverse code-to-value mapping for conducts

  my %con_to_val;
  for my $v (keys %$bitmap_def) {
    $con_to_val{$bitmap_def->{$v}} = $v;
  }

	#--- get ordered list of conducts

	for my $c (@{$nh_def->{'nh_conduct_ord'}}) {
    if($c eq 'elbe' && defined $elbereths && !$elbereths) {
      push(@conducts, $c);
      last;
    }
    my $v = $con_to_val{$c};
		if($conduct_bitfield & $v) {
      push(@conducts, $c);
		}
	}

  #--- return depending on context

  return wantarray ? @conducts : scalar(@conducts);
}


#===========================================================================
# Return ordered list of variant shortcodes (on argument not true); or
# hashref of shortcode->displayname (on argument true)
#===========================================================================

sub nh_variants
{
  my $flag = shift;

  if($flag) {
    return $nh_def->{'nh_variants_def'};
  } else {
    return @{$nh_def->{'nh_variants_ord'}};
  }
}


#===========================================================================
# Return list/arrayref of roles/races/genders/alignments for given variant.
#===========================================================================

sub nh_char
{
  #--- arguments

  my $variant = shift;
  my $cat = shift;

  return undef if $cat !~ /^(roles|races|genders|aligns)$/;

  #--- check if known variant

  return undef if !exists $nh_def->{'nh_variants'}{$variant};

  #--- check if the category is defined

  return undef if !exists $nh_def->{'nh_variants'}{$variant}{$cat};

  #--- return the list

  return 
    wantarray ? 
    @{$nh_def->{'nh_variants'}{$variant}{$cat}} :
    $nh_def->{'nh_variants'}{$variant}{$cat};
}



#===========================================================================
# Function returns true if all of the available roles/races/genders/aligns
# are defined in the configuration for given variant.
#===========================================================================

sub nh_combo_defined
{
  my $variant = shift;

  return
    !exists $nh_def->{'nh_variants'}{$variant}{'roles'}
    || !exists $nh_def->{'nh_variants'}{$variant}{'races'}
    || !exists $nh_def->{'nh_variants'}{$variant}{'genders'}
    || !exists $nh_def->{'nh_variants'}{$variant}{'aligns'}
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

sub nh_combo_valid_by_rules
{
  #--- arguments (in lowercase)

  my (
    $variant,
    $role,
    $race,
    $gender,
    $alignment
  ) = map { lc } @_;

  #--- default variant is 'nh', no need to define rules
  #--- for variants that have the exact same combinations
  #--- allowed as vanilla

  if(!exists($nh_def->{'nh_combo_rules_def'}{$variant})) {
    $variant = 'nh';
  }

  #--- iterate over all rules (start)

  for my $rule (@{$nh_def->{'nh_combo_rules_def'}{$variant}}) {

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
# This is alternative to nh_combo_valid_by_rules() that decides combo's
# validity by searching list of all possible combos. Unlike the rules
# based validation, this doesn't fallback to 'nh' as default variant.
#===========================================================================

sub nh_combo_valid_by_enum
{
  #--- arguments (in lowercase)

  my (
    $variant,
    $role,
    $race,
    $gender,
    $alignment
  ) = map { lc } @_;

  #--- return false if no list def exists for given variant

  if(!exists($nh_def->{'nh_combo_list_def'}{$variant})) {
    return 0;
  }

  #--- search the list

  if(
    grep {
      lc($_->[0]) eq $role
      && lc($_->[1]) eq $race
      && lc($_->[2]) eq $gender
      && lc($_->[3]) eq $alignment
    } @{$nh_def->{'nh_combo_list_def'}{$variant}}
  ) {
    return 1;
  } else {
    return 0;
  }
}



#===========================================================================
# Combine the two combo validation functions into one.
#===========================================================================

sub nh_combo_valid
{
  my $variant = $_[0];

  #--- if the given variant does not all of the allowable character
  #--- categories defined, then we do not perform combo validity check at
  #--- all and just return true

  return 1 if !nh_combo_defined($variant);

  #--- combine the two validation methods

  return nh_combo_valid_by_enum(@_) || nh_combo_valid_by_rules(@_);
}



#===========================================================================
# Function to initialize table of role-race-alignment combos (gender is left
# out). It returns hashref with two keys:
# - table -- contains three dimensional array reference
# - idx -- contains hash ref with {role}{race}{align} index to above table;
#          the index is understood as triplet of indexes into the 3-d array
#===========================================================================

sub nh_combo_table_init
{
  #--- arguments

  my (
    $variant,
    $func
  ) = @_;

  #--- init the structure

  my @table;
  my %idx;
  my %ct = ( 'table' => \@table, 'idx' => \%idx, 'variant' => $variant );

  #--- init the table
  # value of -1 marks unavailable combo

  my $i = 0;
  for my $role (nh_char($variant, 'roles')) {
    my @ary_races;
    my $j = 0;
    for my $race (nh_char($variant, 'races')) {
      my @ary_aligns;
      my $k = 0;
      for my $align (nh_char($variant, 'aligns')) {
        my $val = 0;
        for my $gender (nh_char($variant, 'genders')) {
          $val ||= nh_combo_valid($variant, $role, $race, $gender, $align);
        }
        if($func) {
          $val = &$func($role, $race, $align, $val);
        } else {
          $val = $val ? undef : -1;
        }
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

sub nh_combo_table_cell
{
  my ($ct, $role, $race, $align, $val) = @_;
  my ($i, $j, $k);

  ($role, $race, $align) = map { lc } ($role, $race, $align);

  if(!exists $ct->{'idx'}{$role}{$race}{$align}) {
    die sprintf('Invalid character combination %s-%s-%s', $role, $race, $align);
  }
  ($i, $j, $k) = @{$ct->{'idx'}{$role}{$race}{$align}};
  
  if($val) {
    $ct->{'table'}[$i][$j][$k] = $val;
  }
  return $ct->{'table'}[$i][$j][$k];
}



#===========================================================================
# Combotable iterator. The iterator function is calle for every cell of the
# table and gets value/role/race/alignment as its four arguments.
#===========================================================================

sub nh_combo_table_iterate
{
  my ($ct, $iterator) = @_;
  my $variant = $ct->{'variant'};
  my $cnt = 0;

  my $i = 0;
  for my $role (nh_char($variant, 'roles')) {
    my $j = 0;
    for my $race (nh_char($variant, 'races')) {
      my $k = 0;
      for my $align (nh_char($variant, 'aligns')) {
        my $val = nh_combo_table_cell($ct, $role, $race, $align);
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

sub nh_dnethack_map
{
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
