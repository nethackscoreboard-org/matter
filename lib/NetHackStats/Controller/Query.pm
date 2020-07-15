package NetHackStats::Controller::Query;
use Mojo::Base 'Mojolicious::Controller';
use NetHackStats::Model::DB;
#use NetHack::Config;


# this will serve the front page
sub front {
    my $self = shift;

    # first the most recent ascension in each variant is fetched
    my @variants = $self->app->nh->variants();
    # these are a \% and a \@ - stash wants pointers anyway so this is no problem
    # tuple return wouldn't work if they were passed as whole hash and array
    my ($last_ascs, $vars_ordered) = $self->app->nhdb->get_last_asc_per_var(@variants);

    $self->stash(variants => $vars_ordered,
                vardef => $self->app->nh->variant_names(),
                cur_time => scalar(localtime()),
                last_ascensions => $last_ascs);

    # next get streaks
    $self->stash(streaks => $self->app->nhdb->get_current_streaks());

    # now for recent ascensions
    my @recent_ascs = $self->app->nhdb->get_n_recent_ascs('all', 5);
    $self->stash(ascensions_recent => \@recent_ascs);    

    $self->render(template => 'front', handler => 'tt2');
}

## recent games (deaths or ascensions)
# takes a variant parameter or wildcard 'all',
# found in stash->{var}
sub recent {
    my $self = shift;

    my $var = $self->stash('var');
    my $page = $self->stash('page');
    my $lim = 100;

    my @variants = 'all';
    push @variants, $self->app->nh->variants();

    # limit output unless looking specifically at ascensions for one variant
    my @games;
    if ($page eq 'ascended') {
        if ($var ne 'all' && $var ne 'nh') {
            @games = $self->app->nhdb->get_all_ascs($var);
        } else {
            @games = $self->app->nhdb->get_n_recent_ascs($var, $lim);
        }
    } else {
        @games = $self->app->nhdb->get_n_recent_games($var, $lim);
    }
    # count games for scoreboard
    my $i = 0;
    while ($i < scalar @games) {
        $games[$i]->{n} = $i + 1;
        $i += 1;
    }

    $self->stash(result => \@games,
                 variant => $var,
                 $self->nh->aux_data());

    $self->render(template => $page, handler => 'tt2');
}

# server the gametime speedrun stats
sub gametime {
    my $self = shift;
    my $var = $self->stash('var');
    my $lim = 100;

    # populate list of the fastest 100 ascensions (gametime)
    my @ascensions = $self->app->nhdb->get_n_lowest_gametime($var, $lim);

    # count and rank users by number of sub-20k, sub-10k and sub-5k wins
    $self->stash(sub20 => [ $self->app->nhdb->count_subn_games($var, 20000) ],
                 sub10 => [ $self->app->nhdb->count_subn_games($var, 10000) ],
                 sub5  => [ $self->app->nhdb->count_subn_games($var, 5000) ],
                 variant => $var,
                 $self->nh->aux_data(),
                 result => \@ascensions);

    $self->render(template => 'gametime', handler => 'tt2');
}

1;
