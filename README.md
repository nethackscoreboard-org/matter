I suggest building the individual components rather than
running docker-compose up. Especially if the database service
is not yet ready.
Targets are: base, libs-legacy, libs-mojo, respectively for
the images perl-base, cpan-moo and cpan-mojo.
The targets for live containers are: database, feeder and mojo-web.
chcon -Rt svirt_sandbox_file_t mojo cfg


    Build order:
    0. If necessary, git clean and docker clean.
        `$ git clean -fX`
        `$ ./clean-docker.sh`   # NB: this removes ALL vols/conts/imgs
        `$ ls -laZ mojo legacy` # if your system uses SELinux...
        `$ chcon -Rt svirt_sandbox_file_t mojo`
        `$ chcon -Rt svirt_sandbox_file_t legacy`
    1. Initialise config/environment files for the database.
        `$ ./cfg-init-postgres.sh -f feed_pw -s stats_pw -d db_pw`
    2. Build and run the database image/container.
        `$ docker-compose build database && docker-compose up -d database`
    3. Build the perl images.
        `$ docker-compose build base`
        `$ docker-compose build libs-legacy`
        `$ docker-compose build libs-mojo`
    4. Run config for feeder, start container, then mojo-web
        `$ ./cfg-init-feeder.pl`
        `$ docker-compose build feeder`
        `$ docker-compose up feeder`
        `$ ./cfg-init-mojo.pl`
        `$ docker-compose build mojo-web`
        `$ docker-compose up mojo-web`
