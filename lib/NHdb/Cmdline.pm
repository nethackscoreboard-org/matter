#!/usr/bin/env perl

#=============================================================================
# Processing of the command-line options common to both feeder and stats.
#=============================================================================

package NHdb::Cmdline;

use Moo;

#=============================================================================
#=== ATTRIBUTES ==============================================================
#=============================================================================

# lockfile

has lockfile => (
  is => 'rwp',
);

# do not create lock file flag

has no_lockfile => (
  is => 'rwp',
);



my $lock_global;


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
# Creating and removing of lockfile. These methods take into account the fact
# that some of the command-line options avoid this locking. Unsuccessful
# attempt at locking throws an exception.
#=============================================================================

sub lock
{
  my ($self) = @_;
  my $lockfile = $self->lockfile;

  #--- do nothing when we should not do locking

  return if $self->no_lockfile();

  #--- perform locking

  die "Another instance running, exiting\n" if -f $lockfile;
  open(F, '>', $lockfile) or die "Cannot open lock file $lockfile\n";
  print F $$, "\n";
  close(F);

  #--- register handler incase we error out or get killed
  $lock_global = $lockfile;
  $SIG{__DIE__} = \&die_handler;
  $SIG{INT} = \&int_handler;
  $SIG{TERM} = \&term_handler;
}

sub unlock
{
  my ($self) = @_;

  unlink($self->lockfile);
}

sub die_handler() {
  unlink($lock_global);
}

sub int_handler() {
  unlink($lock_global);
  exit(1);
}

sub term_handler() {
  unlink($lock_global);
  exit(0);
}


#=============================================================================

1;
