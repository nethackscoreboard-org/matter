#!/bin/sh
./create_config.sh
cp css/* /var/www/html
tail -f /dev/null