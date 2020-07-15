package NetHackStats::Controller::Query;
use Mojo::Base 'Mojolicious::Controller';
use NetHackStats::Model::DB;
#use NetHack::Config;


# this will serve the front page
sub front {
    my $self = shift;

    # first the most recent ascension in each variant is fetched
    my %last_ascensions;
    my @variants = $self->app->nh->variants();
    for my $var (@variants) {
        my $row = $self->app->nhdb->get_most_recent_asc($var);
        $last_ascensions{$var} = $row;
    }
    my @variants_ordered = sort {
        $last_ascensions{$a}{'age_raw'}
        <=> $last_ascensions{$b}{'age_raw'}
    } keys %last_ascensions;
    $self->stash(variants => \@variants_ordered,
                vardef => $self->app->nh->variant_names(),
                cur_time => scalar(localtime()),
                last_ascensions => \%last_ascensions);

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
                 cur_time => scalar(localtime()),
                 variants => \@variants,
                 vardef => $self->app->nh->variant_names(),
                 variant => $var);

    $self->render(template => $page, handler => 'tt2');
}

1;
