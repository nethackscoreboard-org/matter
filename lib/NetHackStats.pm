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
    my $r = $self->routes;
    $r->any('/')->to('query#front');
    #$r->any('/recent')->to('query#recent')->name('recent_test');
}

1;
