#!/usr/bin/env perl

#=============================================================================
# Processing of the command-line options common to both feeder and stats.
#=============================================================================

package NHdb::Cmdline;

use Moo;


#=============================================================================
#=== METHODS =================================================================
#=============================================================================

#=============================================================================
# Function that expands list in form ( "arg1,arg2", "arg3,arg4", "arg5" )
# to ( "arg1", "arg2", "arg3", "arg4", "arg5" ).
#=============================================================================

sub _cmd_list_expand
{
  my ($self, @list) = @_;
  my @result;

  foreach my $el (@list) {
    push(@result, split(/,/, $el));
  }

  return @result;
}


#=============================================================================
# Add values to an attribute
#=============================================================================

sub _add_to
{
  my ($self, $where) = splice(@_, 0, 2);
  my $attrval = $self->$where();

  if(!ref $attrval) {
    my $setter = "_set_$where";
    $self->$setter($attrval = []);
  }
  push(@$attrval, $self->_cmd_list_expand(@_));
}


#===============================================================================
# Return 'on', 'off' or 'undefined' depending on the state of an attribute
# passed in as the argument.
#===============================================================================

sub option_state
{
  my ($self, $option) = @_;
  my $value = $self->$option();

  if($value) {
    return 'on';
  } elsif(defined $value) {
    return 'off';
  } else {
    return 'undefined';
  }
}


#=============================================================================

1;
