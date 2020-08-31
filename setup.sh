#!/usr/bin/env bash
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
envsubst < _nhdb-init.sh  > ../bin/nhdb-init.sh
chmod a+x ../bin/nhdb-init.sh
envsubst < _mounts.conf > mounts.conf
cd pginit.d
envsubst < _00_init_users.sh > 00_init_users.sh
for i in *; do
    ln -srf $i $TOPDIR/pods/postgres/init.d/
done
cd $TOPDIR

# copy files to install directories
mkdir -pv $HOST_RUNDIR/
cp -r run/* $HOST_RUNDIR/
cp -r cfg $HOST_RUNDIR/
cp -r lib $HOST_RUNDIR/
mkdir -pv $HOST_WEBDIR
cp -r www/* $HOST_WEBDIR/
cp -r bin/* $HOST_BINDIR/

# build container images
podman build -t nhdb:$LABEL pods/postgres || exit $?
podman build -t cpan-env:$LABEL pods/cpan || exit $?
podman build -t feeder-skel:$LABEL --target skel pods/feeder || exit $?
podman build -t cpan-feeder:$LABEL --build-arg LABEL=$LABEL \
    --target cpan-deps --build-arg RUN=$CONT_RUNDIR pods/feeder || exit $?
podman build -t nhdb-feeder:$LABEL --build-arg LABEL=$LABEL \
    --target small --build-arg RUN=$CONT_RUNDIR pods/feeder || exit $?
podman build -t nhdb-stats:$LABEL pods/stats || exit $?
podman pull nginx:alpine || exit $?
