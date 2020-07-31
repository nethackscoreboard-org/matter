package NHS::Controller::Board; use Mojo::Base 'Mojolicious::Controller';
use NHS::Model::Scores;
use NHdb::Config;
#use NetHack::Config;

sub about {
    my $self = shift;
    my $scr = $self->app->scores;
    my $nhdb = NHdb::Config->instance;

    my $result = $scr->lookup_sources();
    $self->stash(logfiles => $result,
                 urlpath => $nhdb->config()->{logs}{urlpath},
                 cur_time => scalar(localtime()));
    $self->render(template => 'about', handler => 'tt2');
}

# this will serve the front page
sub overview {
    my $self = shift;
    my $scr = $self->app->scores;

    # first the most recent ascension in each variant is fetched
    my @variants = $self->app->nh->variants();
    # these are a \% and a \@ - stash wants pointers anyway so this is no problem
    # tuple return wouldn't work if they were passed as whole hash and array
    my ($last_ascs, $vars_ordered) = $scr->lookup_latest_variant_ascensions(@variants);

    $self->stash(variants => $vars_ordered,
                vardef => $self->app->nh->variant_names(),
                cur_time => scalar(localtime()),
                last_ascensions => $last_ascs);

    # next get streaks
    $self->stash(streaks => $scr->lookup_current_streaks());

    # now for recent ascensions
    $self->stash(ascensions_recent => $scr->lookup_recent_ascensions('all', 5));    

    $self->render(template => 'front', handler => 'tt2');
}

## recent games (deaths or ascensions)
# takes a variant parameter or wildcard 'all',
# found in stash->{var}
sub recent {
    my $self = shift;
    my $scr = $self->app->scores;

    my $var = $self->stash('var');
    my $page = $self->stash('page');
    my $n = 100;

    my @variants = 'all';
    push @variants, $self->app->nh->variants();

    # limit output unless looking specifically at ascensions for one variant
    my $games;
    if ($page eq 'ascended') {
        if ($var ne 'all' && $var ne 'nh') {
            $games = $scr->lookup_all_ascensions($var);
        } else {
            $games = $scr->lookup_recent_ascensions($var, $n);
        }
    } else {
        $games = $scr->lookup_recent_games($var, $n);
    }
    # count games for scoreboard

    $self->stash(result => $games,
                 variant => $var,
                 $self->nh->aux_data());

    $self->render(template => $page, handler => 'tt2');
}

# server the gametime speedrun stats
sub gametime {
    my $self = shift;
    my $scr = $self->app->scores;
    my $var = $self->stash('var');
    my $n = 100;

    # populate list of the fastest 100 ascensions (gametime)
    my $ascensions = $scr->lookup_fastest_gametime($var, $n);

    # count and rank users by number of sub-20k, sub-10k and sub-5k wins
    $self->stash(sub20 => $scr->count_subn_ascensions($var, 20000),
                 sub10 => $scr->count_subn_ascensions($var, 10000),
                 sub5  => $scr->count_subn_ascensions($var, 5000),
                 variant => $var,
                 $self->nh->aux_data(),
                 result => $ascensions);

    $self->render(template => 'gametime', handler => 'tt2');
}

# show statistics for streakers
sub streaks {
    my $self = shift;
    my $scr = $self->app->scores;
    my $var = $self->stash('var');

    $self->stash(result => $scr->lookup_streaks($var),
                 variant => $var,
                 $self->nh->aux_data());
    $self->render(template => 'streaks', handler => 'tt2');
}

# server Z-Scores
sub zscore {
    my $self = shift;
    my $scr = $self->app->scores;
    my $var = $self->stash('var');

    # get variant specific role info etc.
    my $nv = $self->nh->variant($var eq 'all' ? 'nh' : $var);
    my $zscore = $scr->compute_zscore();
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

# conduct page
sub conduct {
    my $self = shift;
    my $scr = $self->app->scores;
    my $var = $self->stash('var');

    $self->stash(result => $scr->lookup_most_conducts($var),
                 variant => $var,
                 $self->nh->aux_data()
                );
    $self->render(template => 'conduct', handler => 'tt2');
}

# lowscore page
sub lowscore {
    my $self = shift;
    my $scr = $self->app->scores;
    my $var = $self->stash('var');

    $self->stash(result => $scr->lookup_lowscore_ascensions($var),
                 variant => $var,
                 $self->nh->aux_data()
                );
    $self->render(template => 'lowscore', handler => 'tt2');
}

sub firstasc {
    my $self = shift;
    my $var = $self->stash('var');
    my $scr = $self->app->scores;

    # only run for those enabled in the config JSON
    # this seems to be the only place we directly
    # use NHdb::Config
    my $nhdb = NHdb::Config->instance;
    return if !$nhdb->first_to_ascend($var);

    my $nv = $self->nh->variant($var);
    my $games = $scr->lookup_first_to_ascend($var);
    my %data = (table => $nv->combo_table()->{table},
                roles => $nv->roles(),
                races => $nv->races(),
                genders => $nv->genders(),
                aligns => $nv->alignments(),
                roles_def => $self->nh->config()->{nh_roles_def},
                races_def => $self->nh->config()->{nh_races_def},
                variant => $var,
                cur_time => scalar(localtime()),
                variants => [ $nhdb->first_to_ascend() ],
                result => $games,
                vardef => $self->nh->variant_names());
    foreach my $row (@$games) {
        # add entries to combo table
        $nv->combo_table_cell(
            $row->{role}, $row->{race}, $row->{align}, $row->{name}
        );
    }
    $data{unascend} = [];
    $data{byplayer} = {};
    $nv->combo_table_iterate(sub {
            my ($val, $role, $race, $align) = @_;

            # unascended combos
            if(!defined($val)) {
                push(
                    @{$data{unascend}},
                    sprintf('%s-%s-%s', ucfirst($role), ucfirst($race), ucfirst($align))
                );
            }

            # combos by users
            if($val && $val ne '-1') {
                if(!exists $data{byplayer}{$val}) {
                    $data{byplayer}{$val}{cnt} = 0;
                    $data{byplayer}{$val}{games} = [];
                }
                $data{byplayer}{$val}{cnt}++;
                push(
                    @{$data{byplayer}{$val}{games}},
                    sprintf('%s-%s-%s', ucfirst($role), ucfirst($race), ucfirst($align))
                );
            }
        });

    #--- create sorted index for 'byplayer'

    # ordering by number of games (in 'cnt' key), in case of ties
    # we want to use the original order from database query

    $data{byplayer_ord} = [ sort {
            if($data{byplayer}{$b}{cnt} != $data{byplayer}{$a}{cnt}) {
                $data{byplayer}{$b}{cnt} <=> $data{byplayer}{$a}{cnt}
            } else {
                my ($plr_a) = grep { $_->{name} eq $a } @$games;
                my ($plr_b) = grep { $_->{name} eq $b } @$games;
                $plr_a->{n} <=> $plr_b->{n};
            }
        } keys %{$data{byplayer}} ];

    # generate page
    $self->stash(%data);
    $self->render(template => 'firstasc', handler => 'tt2');
}

1;
