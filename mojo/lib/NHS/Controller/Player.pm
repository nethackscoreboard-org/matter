package NHS::Controller::Player;
use Mojo::Base 'Mojolicious::Controller';
use NHS::Model::Scores;
use Log::Log4perl qw(get_logger);
#use NetHack::Config;

#============================================================================
# Create structure for calendar view of ascensions (ie. ascensions by years/
# /months)
#============================================================================

sub ascensions_calendar_view
{
  my $data = shift;
  my %acc;
  my @result;

  #--- assert data received

  if(scalar(@$data) == 0) { die 'No data received by ascensions_calendar_view()'; }

  #--- create year/months counts in hash

  for my $ascension (@$data) {
    $ascension->{'endtime'} =~ /^(\d{4})-(\d{2})-\d{2}\s/;
    my ($year, $month) = ($1, $2+0);
    if(!exists($acc{$year}{$month})) { $acc{$year}{$month} = 0; }
    $acc{$year}{$month}++;
    if(!defined($acc{'year_low'}) || $year < $acc{'year_low'}) {
      $acc{'year_low'} = $year;
    }
    if(!defined($acc{'year_hi'}) || $year > $acc{'year_hi'}) {
      $acc{'year_hi'} = $year;
    }
  }

  #--- now turn the data into an array

  for(my $year = $acc{'year_low'}; $year <= $acc{'year_hi'}; $year++) {
    my @row = ($year);
    my $yearly_total = 0;
    for my $month (1..12) {
      my $value = exists($acc{$year}{$month}) ? $acc{$year}{$month} : 0;
      push(@row, $value);
      $yearly_total += $value;
    }
    push(@row, $yearly_total);
    push(@result, \@row);
  }

  #--- finish

  return \@result;
}

#============================================================================
# Order an array by using reference array
#============================================================================

sub array_sort_by_reference
{
  my $ref = shift;
  my $ary = shift;
  my @result;

  for my $x (@$ref) {
    if(grep { $x eq $_ } @$ary) {
      push(@result, $x);
    }
  }
  return \@result;
}

sub hpush (\%@) {
    my ($hash, %add) = @_;
    $hash->{$_} = $add{$_} for keys %add;
}

# this will serve the main player page
sub overview {
    my $self = shift;
    my $name = $self->stash('name');
    my $var = $self->stash('var');
    my $scr = $self->app->scores;
    my $player_combos;
    my %data;

    # fetch linked account information
    $data{lnk_accounts} = $scr->lookup_linked_accounts($name);

    # now for ascensions
    my $ascensions = $scr->lookup_player_ascensions($var, $name);
    my %ascs_by_rowid = map { $_->{'rowid'}, $_ } @$ascensions;
    hpush %data, (result_ascended => $ascensions,
                games_count_asc => scalar(@$ascensions));

    # include Z-Score
    $data{zscore} = $scr->compute_zscore($name);

    # count total games (not-scummed), scummed games, 
    # first ever game (problems with some data sources e.g. devnull) & 15 recent games
    my $count_games = $scr->count_games($var, $name);
    my $recent_games = $scr->lookup_recent_player_games($var, $name, 15, $count_games, -1);
    print "$recent_games\n";
    hpush %data, (games_count_all => $count_games,
                games_count_scum => $scr->count_scums($var, $name),
                games_first => $scr->lookup_first_game($var, $name),
                result_recent => $recent_games,
                games_last => $recent_games->[0]);

    # total play time --- this needs work, often gives a nonsense result
    # also maybe want a less hard-coded way of deciding which ones to count
    if ($var !~ /^(nh4|ace|nhf|dyn|fh)$/) {
        # also, it seems we exclude certain variants *pages* from entering into this
        # caclulation, but if we're all, there's no logic to prevent counting data
        # from all those variants that we are excluding from a realtime sum on their
        # variant pages...
        $data{total_duration} = $scr->sum_play_duration($var, $name);
    }

    # get number of games played per role, race, etc. & how many ascended
    # only do this for variants with defined variant/role combination
    if ($var eq 'all' || $self->nh->variant($var)->combo_defined()) {
        hpush %data, (result_roles_all => $scr->enumerate_games_by($var, $name, 'role'),
                    result_races_all => $scr->enumerate_games_by($var, $name, 'race'),
                    result_aligns_all => $scr->enumerate_games_by($var, $name, 'align'),
                    result_roles_asc => $scr->enumerate_ascensions_by($var, $name, 'role'),
                    result_races_asc => $scr->enumerate_ascensions_by($var, $name, 'race'),
                    result_aligns_asc => $scr->enumerate_ascensions_by($var, $name, 'align'));
    }
    
    ## next get streaks
    my $streaks = $scr->lookup_player_streaks($var, $name);
    my %streaks_count = (all => 0, open => 0);
    foreach my $row (@$streaks) {
        $streaks_count{all}++ if $row->{wins} > 1;
        $streaks_count{open}++ if $row->{open};
    }
    hpush %data, (streaks => $streaks,
                streaks_count => \%streaks_count);

    ## z-roles...
    # fall-back on vanilla if variant is 'all'
    my $nv = $self->nh->variant($var eq 'all' ? 'nh' : $var);
    if ($nv->roles()) {
        $data{z_roles} = [ @{$nv->roles()} ];
    } else {
        $data{z_roles} = [
            sort
            grep { $_ ne 'all' }
            keys %{$data{zscore}{val}{$name}{$var}}
        ];
    }

    hpush %data, (
                nh_roles => $nv->roles(),
                nh_races => $nv->races(),
                nh_aligns => $nv->alignments(),
                cur_time => scalar(localtime()),
                #name => $name already stashed
                variant => $var,
                variants => ['all', $self->nh->variants()],
                # this special sort doesn't make sense
                # without $player_combos having been defined
                # - usually this comes from the update table,
                # shows new stuff. could perhaps be done
                # with recent games instead.
                # currently Z-score breakdown table only works
                # with unsorted variants (above); below code
                # breaks it
                #variants => array_sort_by_reference(
                #    [ 'all', $self->nh->variants() ],
                #    [ keys %{$player_combos->{$name}} ]
                #),
                vardef => $self->nh->variant_names()
            );
    if ($data{games_count_asc}) {
        $data{result_calendar} = ascensions_calendar_view($data{result_ascended});
    }

    $self->stash(%data);
    $self->render(template => 'player', handler => 'tt2');
}

## recent games (deaths or ascensions)
# takes a variant parameter or wildcard 'all',
# found in stash->{var}
sub recent {
    my $self = shift;

    my $name = $self->stash('name');
    my $var = $self->stash('var');
    my $page = $self->stash('page');
    my $n = 100;

    my @variants = 'all';
    push @variants, $self->app->nh->variants();

    # limit output unless looking specifically at ascensions for one variant
    my $games;
    if ($page eq 'ascended') {
        $games = $self->app->scores->lookup_player_ascensions($var, $name);
    } else {
        $games = $self->app->scores->lookup_player_games($var, $name, $n);
    }

    # here we show recent games numbered with 1 as the most recent
    # old-style site counts backward from N where N is the number of games
    # recorded - consider fixing this
    $self->stash(result => $games,
                 variant => $var,
                 $self->nh->aux_data());

    $self->render(template => "player/$page", handler => 'tt2');
}

# server the gametime speedrun stats
sub gametime {
    my $self = shift;
    my $var = $self->stash('var');
    my $name = $self->stash('name');

    # populate list of the fastest player ascensions (gametime)
    my $ascensions = $self->app->scores->lookup_player_gametime($var, $name);
    $self->stash(result => $ascensions,
                 variant => $var,
                 $self->nh->aux_data());
    $self->render(template => 'player/gametime', handler => 'tt2');
}

# show statistics for streakers
sub streaks {
    my $self = shift;
    my $var = $self->stash('var');
    my $name = $self->stash('name');

    $self->stash(result => $self->app->scores->lookup_player_streaks($var, $name),
                 variant => $var,
                 $self->nh->aux_data());
    $self->render(template => 'player/streaks', handler => 'tt2');
}

# conduct page
sub conduct {
    my $self = shift;
    my $scr = $self->app->scores;
    my $var = $self->stash('var');
    my $name = $self->stash('name');

    $self->stash(result => $scr->lookup_most_conducts($var, $name),
                 variant => $var,
                 $self->nh->aux_data()
                );
    $self->render(template => 'player/conduct', handler => 'tt2');
}

# lowscore page
sub lowscore {
    my $self = shift;
    my $scr = $self->app->scores;
    my $var = $self->stash('var');
    my $name = $self->stash('name');

    $self->stash(result => $scr->lookup_lowscore_ascensions($var, $name),
                 variant => $var,
                 $self->nh->aux_data()
                );
    $self->render(template => 'player/lowscore', handler => 'tt2');
}

1;
