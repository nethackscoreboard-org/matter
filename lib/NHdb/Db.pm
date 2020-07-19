#!/usr/bin/env perl

#=============================================================================
# Connecting to the database
#=============================================================================

package NHdb::Db;

use Moo;
use DBI;
use Carp;
use Ref::Util qw(is_blessed_hashref);


#=============================================================================
#=== ATTRIBUTES ==============================================================
#=============================================================================

# connection id

has id => (
  is => 'ro',
  required => 1,
);

# reference to NHdb::Config instance

has config => (
  is => 'ro',
  required => 1,
  isa => sub {
    croak "NHdb::Db constructor needs NHdb::Config instance"
    if !is_blessed_hashref($_[0]) || !$_[0]->isa('NHdb::Config');
  },
);

# DBI handle

has handle => (
  is => 'lazy',
  builder => '_db_connect',
);


sub _db_connect
{
  my ($self) = @_;
  my $c = $self->config()->config();
  my $id = $self->id();

  #--- reject unconfigured database connection id and connection specifics

  croak qq{Undefined database connection "$id"}
    if !exists $c->{'db'}{$id};

  my $conn = $c->{'db'}{$id};

  croak qq{Undefined database name for connection "$id"}
    if !$conn->{'dbname'};
  croak qq{Undefined database user for connection "$id"}
    if !$conn->{'dbuser'};
  croak qq{Undefined password for database user "$conn->{'dbuser'}"}
    if !$c->{'auth'} || !$c->{'auth'}{$conn->{'dbuser'}};

  #--- create the source string

  my $src = 'dbi:Pg:dbname=' . $conn->{'dbname'};
  $src .= ';host=' . $conn->{'dbhost'} if $conn->{'dbhost'};
  $src .= ';port=' . $conn->{'dbport'} if $conn->{'dbport'};

  #--- connect to the database

  my $dbh = DBI->connect(
    $src,
    $conn->{'dbuser'},
    $c->{'auth'}{$conn->{'dbuser'}},
    {
      AutoCommit => 1,
      pg_enable_utf => 1,
    }
  );

  if(!ref($dbh)) {
    croak 'Failed to open database handle (' . DBI::errstr . ')';
  }

  return $dbh;
}


#=============================================================================

1;
