#!/usr/bin/env perl

#=============================================================================
# Processing of the command-line options for the feeder.
#=============================================================================

package NHdb::Stats::Cmdline;

use Moo;
with 'MooX::Singleton';
extends 'NHdb::Cmdline';

use Getopt::Long;
use Carp;


#=============================================================================
#=== ATTRIBUTES ==============================================================
#=============================================================================

# this needs to be passed in by the caller on the instantiation and is only
# used in the usage message

has aggr_pages => (
  is => 'ro',
);

has summ_pages => (
  is => 'ro',
);

# the following attributes come from parsing the command-line options

has variants => (
  is => 'rwp',
  default => sub { [] },
);

has players => (
  is => 'rwp',
  default => sub { [] },
);

has process_players => (
  is => 'rwp',
  default => 1,
);

has process_aggregate => (
  is => 'rwp',
  default => 1,
);

has pages => (
  is => 'rwp',
  default => sub { [] },
);

has force => (
  is => 'rwp',
);


#=============================================================================
# Initialize the object according to the command-line options given
#=============================================================================

sub BUILD {
  my ($self, $args) = @_;

  if(!GetOptions(
    'variant=s' => sub { $self->_add_to('variants', $_[1]); },
    'force'     => sub { $self->_set_force($_[1]); },
    'player=s'  => sub { $self->_add_to('players', $_[1]); },
    'players!'  => sub { $self->_set_process_players($_[1]); },
    'aggr!'     => sub { $self->_set_process_aggregate($_[1]); },
    'pages=s'   => sub { $self->_add_to('pages', $_[1]); },
    'help'      => sub { $self->help(); exit(0); },
  )) {
    print STDERR "Invalid command-line argument\n";
    $self->help();
    exit(1);
  }
};


#=============================================================================
#=== METHODS =================================================================
#=============================================================================

#============================================================================
# Display usage help.
#============================================================================

sub help
{
  my $self = shift;
  my @pages;

  if(ref($self->aggr_pages())) {
    push(@pages, keys %{$self->aggr_pages()});
  }

  if(ref($self->summ_pages())) {
    push(@pages, keys %{$self->summ_pages()});
  }

  print "Usage: nhdb-stats.pl [options]\n\n";
  print "  --help         get this information text\n";
  print "  --variant=VAR  limit processing to specified variant(s)\n";
  print "  --force        force processing of everything\n";
  print "  --player=NAME  update only given player\n";
  print "  --noplayers    disable generating player pages\n";
  print "  --noaggr       disable generating aggregate pages\n";
  print "  --pages=PAGES  limit processing to specified pages (";
  print join(',', sort @pages);
  print ")\n";
  print "\n";
}


#=============================================================================
# Helper methods to quickly determine whether --players, --variants and
# --pages were specified
#=============================================================================

sub has_players
{
  my $self = shift;

  return scalar(@{$self->players()})
}

sub has_variants
{
  my $self = shift;

  return scalar(@{$self->variants()})
}

sub has_pages
{
  my $self = shift;

  return scalar(@{$self->pages()})
}


#=============================================================================

1;
