package NetHackStats;
use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::TemplateToolkit;
use NetHackStats::Model::DB;
use NetHack::Config;
use strict;
use warnings;
use feature 'state';
use utf8;

#use NetHackStats::Model::NH;
#

sub startup {
    my $self = shift;
    $self->helper(nhdb => sub { state $nhdb =
            NetHackStats::Model::DB->new($self) });
    $self->helper(nh => sub { state $nh =
            NetHack::Config->new(config_file => "cfg/nethack_def.json")});
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
    $r->any('/')->to('query#front');
    $r->any('/index')->to('query#front');
    
    # recent/ascended games 
    # my redirects to .all don't work, not super important though
    $r->add_type(recent_page => ['recent', 'ascended']);
    $r->any('/<page:recent_page>.<var:variants>')->to('query#recent');
    $r->any('/<page:recent_page>')->to('query#recent', var => 'all');

    # low turncount
    $r->any('/gametime.<var:variants>')->to('query#gametime');
    $r->any('/gametime')->to('query#gametime', var => 'all');
}

1;
