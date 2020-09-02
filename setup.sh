#!/usr/bin/env bash
set -x
source defs/setup_def.sh
skip_pass="true"

getpw () {
    user=$1
    dir=$2
    stty_orig=`stty -g`
    stty -echo
    echo -n "enter password for $user: "
    read temp; echo
    echo $temp > $dir/$user
    stty $stty_orig
}

if [ -e $secrets/root ] && \
    [ -e $secrets/$FEEDER_DBUSER ] && \
    [ -e $secrets/$STATS_DBUSER ]; then
    if [[ "$skip_pass" != "true" ]]; then
        echo -n "use old passwords? (Y/n) "
        read temp;
        if [[ $temp == 'Y' ]]; then
            skip_pass="true"
        else
            unset skip_pass
        fi
    fi
else
    unset skip_pass
fi

# chooose passwords
if [[ -z $skip_pass ]]; then
    mkdir -p $secrets
    getpw root $secrets
    getpw $FEEDER_DBUSER $secrets
    getpw $STATS_DBUSER $secrets
    export FEEDER_PASS=`cat $secrets/$FEEDER_DBUSER`
    export STATS_PASS=`cat $secrets/$STATS_DBUSER`
    envsubst < defs/_auth.json > $secrets/auth.json
    unset FEEDER_PASS
    unset STATS_PASS
fi

# run envsubst on some files needing preprocessing
export TOPDIR=$PWD
mkdir -pv cfg
mkdir -pv bin
cd defs
cp nethack_def.json logging.conf ../cfg/
envsubst < _nhdb_def.json > ../cfg/nhdb_def.json
envsubst < _init-nhdb.sh  > ../bin/init-nhdb
envsubst < _nhdb-feeder.sh  > ../bin/nhdb-feeder
envsubst < _nhdb-mojo.sh  > ../bin/nhdb-mojo
chmod a+x ../bin/*
envsubst < _mounts.conf > mounts.conf
envsubst < _00_init_users.sh > pginit.d/00_init_users.sh
chmod a+x pginit.d/00_init_users.sh
cd pginit.d
mkdir -pv $TOPDIR/pods/postgres/init.d
for i in *; do
    ln -srf $i $TOPDIR/pods/postgres/init.d/
done
cd $TOPDIR

# copy files to install directories for aggregator
mkdir -pv $HOST_RUNDIR/logs
cp run/nhdb-feeder.pl $HOST_RUNDIR/
cp -r cfg $HOST_RUNDIR/
cp -r lib $HOST_RUNDIR/

# copy files to install directories for mojo front-end
mkdir -pv $HOST_MOJDIR
cp -r cfg $HOST_MOJDIR/
cp -r run/templates $HOST_MOJDIR/
cp -r run/script $HOST_MOJDIR/
mkdir -pv $HOST_WEBDIR
cp -r www/* $HOST_WEBDIR/

cp -r bin/* $HOST_BINDIR/

if [[ $# -ge 0 && $1 == "--skip-pods" ]]; then
    exit 0
fi

pods/build.sh
