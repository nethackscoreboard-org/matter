#!/usr/bin/env perl

#=============================================================================
# Processing of the command-line options for the feeder.
#=============================================================================

package NHdb::Feeder::Cmdline;

use Moo;
with 'MooX::Singleton';

use Getopt::Long;
use Carp;


#=============================================================================
#=== ATTRIBUTES ==============================================================
#=============================================================================

# --logfiles
# display list of configured sources and exit

has show_logfiles => (
  is => 'rwp',
);

# --variant=VARIANT
# select only specified variant(s), variants can be separated by commas and
# the option can be specified multiple times

has variants => (
  is => 'rwp',
  default => sub { [] },
);

# --server=SERVER
# select only specified server(s), servers can be separated by commas and
# the option can be specified multiple times

has servers => (
  is => 'rwp',
  default => sub { [] },
);

# --logid=LOGID
# select only specified log; at this moment multiple logs are not supported

has logid => (
  is => 'rwp',
);

# --purge
# remove all games matching criteria specified with --server, --variant
# and --logid

has purge => (
  is => 'rwp',
);

# --[no]oper
# set or clear the "operational" bit for matching sources

has operational => (
  is => 'rwp',
);

# --[no]static
# set or clear the "static" bit for matching sources

has static => (
  is => 'rwp',
);

# --pmap-add=SRCNAME/SRV=DSTNAME
# --pmap-remove=SRCNAME/SRV
# --pmap-list
# Options for managing player name mappings

has pmap_add => (
  is => 'rwp',
);

has pmap_remove => (
  is => 'rwp',
);

has pmap_list => (
  is => 'rwp',
);

# do not create lock file flag

has no_lockfile => (
  is => 'rwp',
);


#=============================================================================
# Initialize the object according to the command-line options given
#=============================================================================

sub BUILD {
  my ($self, $args) = @_;

  if(!GetOptions(
    'logfiles'      => sub { $self->_set_show_logfiles(1);
                             $self->_set_no_lockfile(1); },
    'variant=s'     => sub { $self->_add_to('variants', $_[1]); },
    'server=s'      => sub { $self->_add_to('servers', $_[1]); },
    'logid=s'       => sub { $self->_set_logid($_[1]); },
    'purge'         => sub { $self->_set_purge(1); },
    'oper!'         => sub { $self->_set_operational($_[1]);
                             $self->_set_no_lockfile(1); },
    'static!'       => sub { $self->_set_static($_[1]);
                             $self->_set_no_lockfile(1); },
    'pmap-add=s'    => sub { $self->_add_to('pmap_add', $_[1]);
                             $self->_set_no_lockfile(1); },
    'pmap-remove=s' => sub { $self->_add_to('pmap_remove', $_[1]);
                             $self->_set_no_lockfile(1); },
    'pmap-list'     => sub { $self->_set_pmap_list(1);
                             $self->_set_no_lockfile(1); },
    'help'          => sub { help(); exit(0); },
  )) {
    print STDERR "Invalid command-line argument\n";
    help();
    exit(1);
  }
};


#=============================================================================
#=== METHODS =================================================================
#=============================================================================

#=============================================================================
# Help message.
#=============================================================================

sub help
{
  print <<EOHD;
Usage: nhdb-feeder.pl [options]

  --help            get this information text
  --logfiles        display configured logfiles, then exit
  --variant=VAR     limit processing to specified variant(s)
  --server=SRV      limit processing to specified server(s)
  --logid=ID        limit processing to specified logid
  --purge           delete database content
  --oper            enable/disable source(s)
  --static          enable/disable static flag on source(s)
  --pmap-list       list existing player name mappings
  --pmap-add=MAP    add player name mapping(s)
  --pmap-remove=MAP remove player name mapping(s)

EOHD
}

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


#=============================================================================

1;
