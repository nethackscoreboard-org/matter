#!/bin/sh
cd /nhs
# first run?
if [ !-e /var/log/feeder.out ]; then
    sleep 120 # wait for the database to be properly up
fi

if [ -e /init/nhdb-feeder.pl ]; then
    mv /init/nhdb-feeder.pl .
fi
./nhdb-feeder.pl --server=hdf,hfa,hfe 2>>/var/log/feeder.err >>/var/log/feeder.out
morbo --listen http://*:8082 script/net_hack_stats 2>>/var/log/morbo.err >>/var/log/morbo.out
while true; do
    sleep 900
    ./nhdb-feeder.pl --server=hdf,hfa,hfe 2>>/var/log/feeder.err >>/var/log/feeder.out
done
