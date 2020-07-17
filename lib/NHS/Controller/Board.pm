package NHS::Controller::Board; use Mojo::Base 'Mojolicious::Controller';
use NHS::Model::Scores;
#use NetHack::Config;


# this will serve the front page
sub overview {
    my $self = shift;

    # first the most recent ascension in each variant is fetched
    my @variants = $self->app->nh->variants();
    # these are a \% and a \@ - stash wants pointers anyway so this is no problem
    # tuple return wouldn't work if they were passed as whole hash and array
    my ($last_ascs, $vars_ordered) = $self->app->scores->lookup_latest_variant_ascensions(@variants);

    $self->stash(variants => $vars_ordered,
                vardef => $self->app->nh->variant_names(),
                cur_time => scalar(localtime()),
                last_ascensions => $last_ascs);

    # next get streaks
    $self->stash(streaks => $self->app->scores->lookup_current_streaks());

    # now for recent ascensions
    $self->stash(ascensions_recent => [ $self->app->scores->lookup_recent_ascensions('all', 5) ]);    

    $self->render(template => 'front', handler => 'tt2');
}

## recent games (deaths or ascensions)
# takes a variant parameter or wildcard 'all',
# found in stash->{var}
sub recent {
    my $self = shift;

    my $var = $self->stash('var');
    my $page = $self->stash('page');
    my $n = 100;

    my @variants = 'all';
    push @variants, $self->app->nh->variants();

    # limit output unless looking specifically at ascensions for one variant
    my @games;
    if ($page eq 'ascended') {
        if ($var ne 'all' && $var ne 'nh') {
            @games = $self->app->scores->lookup_all_ascensions($var);
        } else {
            @games = $self->app->scores->lookup_recent_ascensions($var, $n);
        }
    } else {
        @games = $self->app->scores->lookup_recent_games($var, $n);
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
    my $n = 100;

    # populate list of the fastest 100 ascensions (gametime)
    my @ascensions = $self->app->scores->lookup_fastest_gametime($var, $n);

    # count and rank users by number of sub-20k, sub-10k and sub-5k wins
    $self->stash(sub20 => [ $self->app->scores->count_subn_games($var, 20000) ],
                 sub10 => [ $self->app->scores->count_subn_games($var, 10000) ],
                 sub5  => [ $self->app->scores->count_subn_games($var, 5000) ],
                 variant => $var,
                 $self->nh->aux_data(),
                 result => \@ascensions);

    $self->render(template => 'gametime', handler => 'tt2');
}

# show statistics for streakers
sub streaks {
    my $self = shift;
    my $var = $self->stash('var');
    my $n = 100;

    $self->stash(result => $self->app->scores->lookup_streaks($var, $n),
                 variant => $var,
                 $self->nh->aux_data());
    $self->render(template => 'streaks', handler => 'tt2');
}

# server Z-Scores
sub zscore {
    my $self = shift;
    my $var = $self->stash('var');

    # get variant specific role info etc.
    my $nv = $self->nh->variant($var eq 'all' ? 'nh' : $var);
    my $zscore = $self->app->scores->compute_zscore();
    my %zscore = %$zscore;
    
    #--- following key holds roles that are included in the z-score table
    #--- for variants that have enumerated their roles in the configuration,
    #--- this simply lists all of them plus 'all'; for variants that do not
    #--- have their roles listed (such as SLASH'EM Extended), this works
    #--- differently: we only list roles that have ascending games.
  
    my @z_roles;
    for my $role (keys %{$zscore{'max'}{$var}}) {
        push @z_roles, $role unless $role eq 'all';
    }
    if(!$nv->roles()) {
        $self->stash(z_roles => [
            'all', @z_roles
        ]);
    } else {
        $self->stash(z_roles => [ 'all', @{$nv->roles()} ]);
    }

    $self->stash(zscore => $zscore,
                 variant => $var,
                 $self->nh->aux_data()
                );

    $self->render(template => 'zscore', handler => 'tt2');
}

1;
