#!/usr/bin/env perl
use Mojolicious::Lite;
app->config(hypnotoad => {listen => ['http://0.0.0.0:8082']});

get '/' => sub {
    shift->reply->static('index.html');
};

app->start;