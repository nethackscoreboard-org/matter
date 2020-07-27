#!/bin/sh
cd /nhs
./nhdb-feeder.pl --server=hdf,hfa,hfe 2>>/var/log/feeder.err >>/var/log/feeder.out
morbo --listen http://*:8082 script/net_hack_stats 2>>/var/log/morbo.err >>/var/log/morbo.out
sleep infinity
