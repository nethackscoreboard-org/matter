---------OVERVIEW---------
The feeder backend code resides in feeder/ and a docker system has
been designed so that nhdb-feeder.pl may run in its own container and
populate the database. The postgresql database also runs in a docker
container, and the database initialisation files are in postgres/.
The mojo web-framework front-end code is in mojo/, which again has
its own docker container. This is a work-in-progress and currently
the front-page, recent, ascended, streaks, zscore pages are functional.
In addition, /players/$name pages are available, including overview
and per-player versions of the recent, ascended, streaks and gametime
are available at /players/$name/recent, /../ascended, etc.

----BUILD AND RUN-----
Build and start docker services with init.sh
The script assumes a clean git tree and no pre-existing docker
containers or images running NHS. Passwords for nhdbfeeder/nhdbstats
or the database password itself may be given by command-line.
 `$ ./init.sh -f feedpw -s statspw -d dbpw`
Additionally, if you use SELinux, you probably need to use the -S flag
to fix SELinux flags on the directories feeder/ and mojo/ for their
bind mounts to the built containers.

An earlier version of init.sh was renamed to reloader.sh. It provides
a lot of options for reloading and refreshing docker services to varying
extents. In most cases it should not be needed. After the initial run
of ./init.sh, simply running `docker compose up mojo-web` should be
sufficient.

NB: if you already have postgresql running on your docker host or another
container with the default port 5432, the database container will fail,
as will everything else.

-----------------------

However, if in some case it is desired, you can use ./reload.sh -R to
refresh persistent volumes (e.g. the volume used by the database container).

The -r flag will re-generate configuration files for postgres,
feeder and mojo. -C will run git clean -fx, which amounts to
essentially the same thing. These commands may change the db
passwords, so renewal of the database volume will also be carried out.

The -I flag will remove all docker images associated with the project.

Note the logic for some of these volume and image removal steps is not
very sophisticated, it is possible you will have stale containers or
images that the init.sh script won't remove (this may be improved upon).

It is also important to note that currently, changing db passwords will
require a full reset of the DB, because of the simple way in which the
passwords for the database are set up on initialisation. This could also
be improved perhaps.

--------- this is all taken care of by init.sh now ----------
I suggest building the individual components rather than
running docker-compose up. Especially if the database service
is not yet ready.
Targets are: base, libs-feeder, libs-mojo, respectively for
the images perl-base, cpan-moo and cpan-mojo.
The targets for live containers are: database, feeder and mojo-web.
chcon -Rt svirt_sandbox_file_t mojo cfg


    Build order:
    0. If necessary, git clean and docker clean.
        `$ git clean -fX`
        `$ ./clean-docker.sh`   # NB: this removes ALL vols/conts/imgs
        `$ ls -laZ mojo feeder` # if your system uses SELinux...
        `$ chcon -Rt svirt_sandbox_file_t mojo`
        `$ chcon -Rt svirt_sandbox_file_t feeder`
    1. Initialise config/environment files for the database.
       Remember, changes to DB config won't update unless you remove
       the persistent volume.
        `$ ./postgres/init.sh -f feed_pw -s stats_pw -d db_pw`
    2. Build and run the database image/container.
        `$ docker-compose build database && docker-compose up -d database`
    3. Build the perl images.
        `$ docker-compose build base`
        `$ docker-compose build libs-feeder`
        `$ docker-compose build libs-mojo`
    4. Run config for feeder, start container, then mojo-web
        `$ ./feeder/init.sh`
        `$ docker-compose build feeder`
        `$ docker-compose up feeder`
        `$ ./mojo/init.sh`
        `$ docker-compose build mojo-web`
        `$ docker-compose up mojo-web`
