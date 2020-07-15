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
        my $row = $self->app->nhdb->get_most_recent_asc_var($var);
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
    my @recent_ascs = $self->app->nhdb->get_n_recent_ascs(5);
    $self->stash(ascensions_recent => \@recent_ascs);    

    $self->render(template => 'front', handler => 'tt2');
}

## recent games
#sub recent {
#    my $self = shift;
#}

1;
