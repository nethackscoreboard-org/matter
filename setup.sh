#!/usr/bin/env bash
set -x
source defs/setup_def.sh
interactive="false"
export TOPDIR=$PWD

getpw () {
    user=$1
    dir=$2
    if [[ "$interactive" == "false" ]]; then
        temp = $(< /dev/urandom tr -dc '[:digit:]' | head -c 20)
    else
        stty_orig=`stty -g`
        stty -echo
        echo -n "enter password for $user: "
        read temp; echo
        stty $stty_orig
    fi
    echo $temp > $dir/$user
}

if [ -e $secrets/root ] && \
    [ -e $secrets/$FEEDER_DBUSER ] && \
    [ -e $secrets/$STATS_DBUSER ]; then
    if [[ "$skip_pass" != "true" ]] && [[ "$interactive" == "true" ]]; then
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
    cd $secrets
    getpw root ./
    getpw $FEEDER_DBUSER ./
    getpw $STATS_DBUSER ./
    export FEEDER_PASS=`cat ./$FEEDER_DBUSER`
    export STATS_PASS=`cat ./$STATS_DBUSER`
    envsubst < $TOPDIR/defs/_auth.json > $secrets/auth.json
    unset FEEDER_PASS
    unset STATS_PASS
    docker secret create root root
    docker secret create $FEEDER_DBUSER $FEEDER_DBUSER
    docker secret create $STATS_DBUSER $STATS_DBUSER
    docker secret create auth.json auth.json
    cd $TOPDIR
fi

# run envsubst on some files needing preprocessing
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
cp -r pods $HOST_PREFIX/
cp -r bin/* $HOST_BINDIR/

cd defs
chmod a+x pginit.d/00_init_users.sh
cd pginit.d
mkdir -pv $HOST_PREFIX/pods/postgres/init.d
for i in *; do
    #ln -srf $i $HOST_PREFIX/pods/postgres/init.d/
    cp $i $HOST_PREFIX/pods/postgres/init.d/
done

if [[ $# -ge 0 && $1 == "--skip-pods" ]]; then
    exit 0
fi

cd $HOST_PREFIX
pods/build.sh
