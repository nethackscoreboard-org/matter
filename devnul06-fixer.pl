#!/usr/bin/env perl
use Array::Contains;

my @entries = ();

while (my $line = readline(STDIN)) {
    my @split = split(' ', $line);
    my $entry = $split[0];
    next if (contains($entry, \@entries));
    push @entries, $entry;
    print $line;
}
