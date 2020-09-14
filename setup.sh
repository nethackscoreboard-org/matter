#!/bin/bash
# now with a lot less silly environment preprocessing

# flag -i is for an actual interactive bash session,
# which normally excludes any kind of script, tho you
# can force it on the shebang line, test [ -t 0 ] is
# used later instead to check for tty input
#export DEBUG="true"
#set -v


do_cleanup () {
    [[ -z "$TOPDIR" ]] && exit 1
    rm -rf $TOPDIR/defs/cfg.out
    rm -rf $TOPDIR/defs/cfg
    rm -rf $TOPDIR/pods/postgres/init.d
    rm -rf $TOPDIR/pods/feeder/{run,stage}
    rm -rf $TOPDIR/pods/mojo/{run,stage}
}

getpw () {
    user=$1
    dir=$2
    if [[ "$tty_in" == "false" ]]; then
        temp=$(< /dev/urandom tr -dc '[:digit:]' | head -c 20)
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

    file=$1

    while IFS= read -r line; do
        # skip empty line or full-line comment
        if [[ -z $line ]] || [[ $line = \#* ]]; then
            continue
        fi

        # attempt to strip inline comments
        if echo $line | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*=".*"[[:space:]]*#'; then
            line=$(echo $line | sed -E 's/^([a-zA-Z_][a-zA-Z0-9_]*=".*")[[:space:]]*#.*$/\1/')

        # having the quotes make pattern-matching cleaner in this case
        elif echo $line | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*=".*"[[:space:]]*#'; then
            line=$(echo $line | sed -E "s/^([a-zA-Z_][a-zA-Z0-9_]*='.*')[[:space:]]*#.*\$/\1/")
        
        # for unquoted case, we look for some whitespace after value and before #
        elif echo $line | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*=.*[[:space:]]+#'; then
            line=$(echo $line | sed -E 's/^([a-zA-Z_][a-zA-Z0-9_]*=.*)[[:space:]]+#.*$/\1/')
        elif echo $line | grep -vqE '^[a-zA-Z_][a-zA-Z0-9_]*='; then
            echo "bad key: $line" >&2
            continue
        fi

        if echo $line | grep -qE "^[a-zA-Z_][a-zA-Z0-9_]*='.*'\$"; then
            # just strip the quotes - don't envsubst on single-quote delimited key
            key=$(echo $line | sed -E "s/^([a-zA-Z_][a-zA-Z0-9_]*)='(.*)'\$/\1/")
            value=$(echo $line | sed -E "s/^([a-zA-Z_][a-zA-Z0-9_]*)='(.*)'\$/\2/")
            export "$key=$value"
        elif echo $line | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*=".*"$'; then
            # strip quotes and envsubst on value
            key=$(echo $line | sed -E 's/^([a-zA-Z_][a-zA-Z0-9_]*)="(.*)"$/\1/')
            value=$(echo $line | sed -E 's/^([a-zA-Z_][a-zA-Z0-9_]*)="(.*)"$/\2/' | envsubst)
            export "$key=$value"
        elif echo $line | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*=.*[[:space:]]*$'; then
            # no quotes to strip, just envsubst the stuff
            key=$(echo $line | sed -E 's/^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)[[:space:]]*$/\1/')
            value=$(echo $line | sed -E 's/^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)[[:space:]]*$/\2/' | envsubst)
            export "$key=$value"
        else
            # somethink funky happened
            echo "bad key/value pair: $line - did not export" >&2
        fi
    done < "$file"
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
                  is also the default when run without tty input.

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
export secrets=${secrets:-/tmp/nhdb-secrets}
if [[ "$DEBUG" == "true" ]]; then
    alias mkdir='mkdir -v'
    alias ln='ln -v'
fi

# check for terminal input
if [ -t 0 ]; then
    tty_in="true"
else
    tty_in="false"
fi

# get some clip options
while [ $# -gt 0 ]; do
    case "$1" in 
        "--auto-gen")
            tty_in="false"
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
  && [[ "$tty_in" == "true" ]]; then
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
    chmod -R a+r $secrets # security issue somewhat
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
mkdir -p cfg cfg.out
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
rm -rf $TOPDIR/pods/postgres/init.d 
mkdir -p $TOPDIR/pods/postgres/init.d
ln -sr pginit.d/* $TOPDIR/pods/postgres/init.d/


cd $TOPDIR
# files for "feeder"
feeder_cfgs="nhdb_def.json nethack_def.json logging.conf"
feeder_libs="NetHack NHdb"
rundir="$TOPDIR/pods/feeder/run"
stage="$TOPDIR/pods/feeder/stage"
rm -rf $stage $rundir		# always clean before staging
mkdir -p $stage/{cfg,lib} $rundir
ln -sr nhdb-feeder.pl $stage/
cd $TOPDIR/defs/cfg && ln -sr $feeder_cfgs $stage/cfg/
cd $TOPDIR/lib      && ln -sr $feeder_libs $stage/lib/
cd $TOPDIR
cp -rL $stage/* $rundir/

# files for "mojo" frontend
mojo_cfgs="nhdb_def.json nethack_def.json mojo-log.conf"
mojo_libs="$feeder_libs NHS NHS.pm"
stage="$TOPDIR/pods/mojo/stage"
rundir="$TOPDIR/pods/mojo/run"
rm -rf $stage $rundir
mkdir -p $stage/{cfg,lib,script} $rundir
ln -sr mojo-stub.pl   $stage/script/nhs
ln -sr www/static     $stage/public
ln -sr www/templates  $stage/templates
cd $TOPDIR/defs/cfg && ln -sr $mojo_cfgs $stage/cfg/
cd $TOPDIR/lib      && ln -sr $mojo_libs $stage/lib/
cd $TOPDIR
cp -rL $stage/* $rundir/

# start building
pods/build.sh

## cleanup if requeseted
if [[ $? -eq 0 ]] && [[ "$autoclean" == "true" ]]; then
    do_cleanup
fi
