package NHS;
use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::TemplateToolkit;
use NHS::Model::Scores 'new';
use NetHack::Config;
use strict;
use warnings;
use feature 'state';
use utf8;


sub startup {
    my $self = shift;
    $self->helper(nh => sub { state $nh =
            NetHack::Config->new(config_file => "cfg/nethack_def.json")});
    $self->helper(scores => sub { state $scores =
            NHS::Model::Scores->new($self) });
    $self->plugin('TemplateToolkit');

    # set up routing roules
    my $r = $self->routes;

    # many pages will have a variant specifier or wildcard 'all'
    # Mojo placeholders let us catch those and save to the controller stash
    # stuff like .html is also saved in the stash as 'format'
    my @vars = ('all');
    push @vars, $self->nh->variants();
    $r->add_type(variants => \@vars);

    # front page!
    $r->any('/')->to('board#overview');
    $r->any('/index')->to('board#overview');
    
    # recent/ascended games 
    # my redirects to .all don't work, not super important though
    $r->add_type(recent_page => ['recent', 'ascended']);
    $r->any('/<page:recent_page>.<var:variants>')->to('board#recent');
    $r->any('/<page:recent_page>')->to('board#recent', var => 'all');

    # low turncount
    $r->any('/gametime.<var:variants>')->to('board#gametime');
    $r->any('/gametime')->to('board#gametime', var => 'all');

    # streak reports
    $r->any('/streaks.<var:variants>')->to('board#streaks');
    $r->any('/streaks')->to('board#streaks', var => 'all');

    # Z-Scores
    $r->any('/zscore.<var:variants>')->to('board#zscore');
    $r->any('/zscore')->to('board#zscore', var => 'all');

	# player views
	$r->any('/players/<:name>.<var:variants>')->to('player#overview');
	$r->any('/players/<:name>')->to('player#overview', var => 'all');
	$r->any('/players/<:name>/streaks.<var:variants>')->to('player#streaks');
	$r->any('/players/<:name>/streaks')->to('player#streaks', var => 'all');
	$r->any('/players/<:name>/<page:recent_page>.<var:variants>')->to('player#recent');
	$r->any('/players/<:name>/<page:recent_page>')->to('player#recent', var => 'all');
	$r->any('/players/<:name>/gametime.<var:variants>')->to('player#gametime');
	$r->any('/players/<:name>/gametime')->to('player#gametime', var => 'all');
}

1;
