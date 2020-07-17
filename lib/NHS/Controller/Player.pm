package NHS::Controller::Player;
use Mojo::Base 'Mojolicious::Controller';
use NHS::Model::Scores;
#use NetHack::Config;

# this will serve the main player page
sub overview {
    my $self = shift;
    my $player = $self->stash('name');
    my $var = $self->stash('var');

    # fetch linked account information
    $self->stash(lnk_accounts => $self->app->scores->lookup_linked_accounts($player));

    # now for ascensions
    my $ascensions = $self->app->scores->lookup_player_ascensions($var, $player);
    my %ascs_by_rowid = map { $_->{'rowid'}, $_ } @$ascensions;
    $self->stash(result_ascended => $ascensions);
    $self->stash(games_count_asc => scalar(@$ascensions));

    # include Z-Score
    $self->stash(zscore => $self->app->scores->compute_zscore());

    ## next get streaks
    #$self->stash(streaks => $self->app->scores->lookup_player_streaks($var, $player));

    #$self->render(template => 'player', handler => 'tt2');
}

## recent games (deaths or ascensions)
# takes a variant parameter or wildcard 'all',
# found in stash->{var}
sub recent {
    my $self = shift;

    my $player = $self->stash('name');
    my $var = $self->stash('var');
    my $page = $self->stash('page');
    my $n = 100;

    my @variants = 'all';
    push @variants, $self->app->nh->variants();

    # limit output unless looking specifically at ascensions for one variant
    my @games;
    if ($page eq 'ascended') {
        @games = $self->app->scores->lookup_player_ascensions($var, $player);
    } else {
        @games = $self->app->scores->lookup_player_games($var, $player, $n);
    }
    # count games for scoreboard
    my $i = 0;
    while ($i < @games) {
        $games[$i]->{n} = $i + 1;
        $i += 1;
    }

    $self->stash(result => \@games,
                 variant => $var,
                 $self->nh->aux_data());

    $self->render(template => "player/$page", handler => 'tt2');
}

# server the gametime speedrun stats
sub gametime {
    my $self = shift;
    my $var = $self->stash('var');
    my $player = $self->stash('name');

    # populate list of the fastest player ascensions (gametime)
    my @ascensions = $self->app->scores->lookup_player_gametime($var, $player);

    $self->render(template => 'player/gametime', handler => 'tt2');
}

# show statistics for streakers
sub streaks {
    my $self = shift;
    my $var = $self->stash('var');
    my $player = $self->stash('name');

    $self->stash(result => $self->app->scores->lookup_player_streaks($var, $player),
                 variant => $var,
                 $self->nh->aux_data());
    $self->render(template => 'player/streaks', handler => 'tt2');
}

1;
