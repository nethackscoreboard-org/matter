#!/usr/bin/env bash
# now with a lot less silly environment preprocessing
export DEBUG="true"
set -x

do_cleanup () {
    [[ -z "$TOPDIR" ]] && exit 1
    rm -rf $TOPDIR/defs/cfg.out
    rm -rf $TOPDIR/defs/cfg
    rm -rf $TOPDIR/pods/postgres/init.d
    rm -rf $TOPDIR/pods/feeder/run
    rm -rf $TOPDIR/pods/mojo/run
}

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

read_env () {
    if [[ $# -ne 1 ]]; then
        exit 1
    fi

    # for within-file substitution to work, we have to import first
    # once without substitution, bootstrap-like
    export $(grep -v '^#' $1 | xargs -0)
    export $(echo $(grep -v '^#' $1 | xargs -0) | envsubst)
}

usage_msg () {
    cat <<-EOF >&2
Usage: $myscript [ --autogen ] [ --clean ] [ --secrets-only ] \\
                 [ --pods-only | --skip-pass ] [ --rm ] \\
                 [ --skip-pods ] [ --help | -h | -? ]

Note: must be run as ./setup.sh from the root of the git tree.
EOF
}

usage_short () {
    if [[ $# -ge 0 ]]; then
    cat <<-EOF >&2
        \`\$ $myscript $*\` - unrecognised CLI option(s)

EOF
    fi
    usage_msg
}

usage () {
    usage_short $*
    exit 1
}

usage_long () {
    # print the short usage message
    usage_short $*
    cat <<-EOF >&2

  Current setup.sh is geared towards provisioning an FCOS instance
that will run NHS inside docker containers. Will possibly expand for
podman initially and direct-OS installation too. The script deals with
three main tasks:
    a) preprocess some config files e.g. cfg/nhdb_def.json
       based on definitions sourced from defs/setup_def.sh and the
       template file defs/_nhdb_def.json - this so that all three
       containers have consisten configuration. Including, crucially,
       information about how to find secret authentication data...
                ...whereas, 
    b) read passwords from STIN or generate them from /dev/urandom,
       then save these data to a directory '\$secrets' - this will be
       bind-mount to containers as /run/secrets.
    c) Link necessary files to subdirectories of pods/ and call
       pods/build.sh, which runs podman/docker build for all required
       images. The images should also be pushed to a repository that
       we control.

  setup.sh may be passed one or more of the following optional flags:

 --auto-gen     - If specified, use /dev/urandom to generate passwords
                  for the services. Some authentication is needed so
                  the containers can interact with each-other, but you
                  may not care what passwords are used. This behaviour
                  is also the default when run without interactive shell.

 --clean        - Remove defs/cfg.out and symbolic links generated for
                  container build process. Do nothing else. Use --rm to
                  automatically clean after successful build run - not
                  enabled by default as the temporary files may help
                  debug.

 --secrets-only - This is necessary for the container host, even if
                  images are built elsewhere and pulled. Indeed, the
                  idea is for FCOS to run this script on Ignition boot,
                  then pull ready-made containers from a repository,
                  rather than build everything from scratch.

 --pods-only/
 --skip-pass    - Do not deal directly with secrets - just build the
                  containers (skip-pass behaviour is the same, but
                  typically assumes pre-existing passwords in \$secrets).
                  Images only need to know where to find the secrets
                  for authentication/initialisation during container
                  runtime. Obviously, the critical stage is initial run
                  of postgres container.


 --rm           - Automatically clean files produced by setup.sh after
                  a successful run. That is, defs/cfg.out, defs/cfg
                  and various symlinks under pods/foo/run.

 --skip-pods    - Run as normal but stop before the actual container
                  build stage. i.e. generate secrets (if not skipped),
                  then pre-process defs/_nhdb_def.json based on the
                  definitions in defs/setup_def.sh. The only difference
                  between this flag and --secrets-only, is that
                  --secrets-only will not generate cfg/nhdb_def.json.

 --help/-h/-?   - Print this lengthy help text.
EOF

    exit 1
}

export TOPDIR=$PWD
skip_pass="false" # by default
secrets_only="false"
skip_pods="false"
autoclean="false"

# gotta do this before trying to source defs/setup_def.sh
# but after function declarations
myscript=$0
setup_name=$(basename $myscript)
if [[ "$myscript" != "./$setup_name" ]]; then
    echo "    \`\$ $myscript\` - do not call with any path that isn't \`./\`" >&2
    myscript="./$setup_name"    # fix because usage_msg prints this variable
    cwd_fail="true"
fi

if [ ! -d ./.git ] || [ ! -d ./defs ] || [ ! -e ./defs/preproc.env ]; then
    echo "working directory $TOPDIR is incorrect" >&2
    cwd_fail="true"
fi

if [[ "$cwd_fail" == "true" ]]; then
    usage_msg
    exit 1
fi

read_env defs/preproc.env
export secrets=${secrets:-$HOME/.secrets/nhdb}
if [[ "$DEBUG" == "true" ]]; then
    alias mkdir='mkdir -v'
    alias ln='ln -v'
fi

# check for interactive terminal session
case $- in
    *i*)
        interactive="true"
        ;;
    *)
        interactive="false"
        ;;
esac

# get some clip options
while [ $# -gt 0 ]; do
    case "$1" in 
        "--auto-gen")
            interactive="false"
            ;;
        "--clean")
            do_cleanup
            exit 0
            ;;
        "--help" | "-h" | "-?")
            usage_long $*
            ;;
        "--secrets-only")
            secrets_only="true"
            ;;
        "--pods-only" | "--skip-pass")
            skip_pass="true"
            ;;
        "--rm")
            autoclean="true"
            ;;
        "--skip-pods")
            skip_pods="true"
            ;;
        *)
            usage $*
            ;;
    esac
    shift
done
     
# check for pre-existing passwords in $secrets
if [ -e $secrets/root ] \
  && [ -e $secrets/$FEEDER_DBUSER ] \
  && [ -e $secrets/$STATS_DBUSER ] \
  && [[ "$skip_pass" != "true" ]] \
  && [[ "$interactive" == "true" ]]; then
    echo -n "use old passwords (detected)? (Y/n) "
    read temp;
    if [[ $temp == 'Y' ]]; then
        skip_pass="true"
    else
        skip_pass="false"
    fi
fi

# chooose passwords
if [[ "$skip_pass" != "true" ]]; then
    mkdir -p $secrets
    cd $secrets
    getpw root ./
    getpw $FEEDER_DBUSER ./
    getpw $STATS_DBUSER ./
    export FEEDER_PASS=`cat ./$FEEDER_DBUSER`
    export STATS_PASS=`cat ./$STATS_DBUSER`
    envsubst < $TOPDIR/defs/envsubst.in/auth.json > $secrets/auth.json
    unset FEEDER_PASS
    unset STATS_PASS
    cd $TOPDIR
fi

# doesn't actually quit very long before the --skip-pods version,
# but there is a difference
if [[ "$secrets_only" == "true" ]]; then
    exit 0
fi

# run envsubst on some files needing preprocessing
# which is now just nhdb_def.json - plus the auth.json
# but that's handled above in the secrets bit
# also symlink all configs to defs/cfg
cd $TOPDIR/defs
mkdir cfg cfg.out
envsubst < envsubst.in/nhdb_def.json > cfg.out/nhdb_def.json

# of course ln can be invoked with multiple targets followed by dir/
# feel silly having had a for loop previously
ln -srf cfg.{out,static}/* $TOPDIR/defs/cfg/

if [[ "$skip_pods" == "true" ]]; then
    # would be an odd use-case, as --skip-pods --rm does nothing
    # unless password generation has actually happened
    [[ "$autoclean" == "true" ]] && do_cleanup
    exit 0
fi

# files for postgres (still workdir defs)
chmod a+x pginit.d/00_init_users.sh
mkdir -p $TOPDIR/pods/postgres/init.d
ln -srf pginit.d/* $TOPDIR/pods/postgres/init.d/


cd $TOPDIR
# files for "feeder"
feeder_cfgs="nhdb_def.json nethack_def.json logging.conf"
feeder_libs="NetHack NHdb"
stage="$TOPDIR/pods/feeder/run"
mkdir -p $stage/{cfg,lib}
ln -srf nhdb-feeder.pl $stage/
cd defs/cfg; ln -srf $feeder_cfgs $stage/cfg/; cd -
cd lib;      ln -srf $feeder_libs $stage/lib/; cd -

# files for "mojo" frontend
mojo_cfgs="nhdb_def.json nethack_def.json mojo-log.conf"
mojo_libs="$feeder_libs NHS NHS.pm"
stage="$TOPDIR/pods/mojo/run"
mkdir -p $stage/{cfg,lib,script}
ln -srf mojo-stub.pl   $stage/script/nhs
ln -srf www/static     $stage/public
ln -srf www/templates  $stage/templates
cd defs/cfg; ln -srf $mojo_cfgs $stage/cfg/; cd -
cd lib;      ln -srf $mojo_libs $stage/lib/; cd -

# start building
pods/build.sh

## cleanup if requeseted
if [[ $? -eq 0 ]] && [[ "$autoclean" == "true" ]]; then
    do_cleanup
fi