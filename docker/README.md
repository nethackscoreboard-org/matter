### Docker setup instructions

After pulling the repository, follow these steps to make the NHS run in a Docker environment. It is assumed that you already run [Docker Desktop](https://www.docker.com/products/docker-desktop) or something comparable for your OS.

Note: All commands should be run from the top-level repo dir.
Security Note: the ssh keys for the user nhs-git are published on
a publically available repository! This is OK for my setup, as my
sshd is not exposed to connections from the wild.
An alternative approach would be to include an ssh-keygen command
here in the setup instructions, along with instructions for copying
the key somewhere the scripts can access it, but with a .gitignore
entry added.

Note also the file .env - this supplies environment variables to
docker-compose.yml e.g. DATABASE_USER and DATABASE_PASSWORD,
these are used to set POSTGRES_USER etc.

 -- Initial Setup --
1. Create a user e.g. nhs-git and copy docker/perl/ssh-key.pub to
    /home/nhs-git/.ssh/authorized_keys, have this user belong to a
    particular group e.g. nhs-dev, which you also need to create.
    # groupadd nhs-dev
    # useradd -m -G nhs-dev nhs-git
    # usermod -aG nhs-dev myuser
2. Ensure this user has read access to the repo and create a symbolic
    link in their home. I have my repository at /devel/nhs-fork, replace
    this with the location of your repo. The repo directory and its parents
    must all be executable to the user nhs-git for this to work.
    # chmod g+r -R .
    # ln -s /devel/nhs-fork /home/nhs-git/
3. Create the images and run the containers. If you are in docker group,
    sudo is not needed.
    $ docker-compose up -d
4. Enter the nhs_perl container.
    $ docker exec -it nhs_perl /bin/sh
5. Call the generated pages from the browser from the url `localhost:8082/index.html`.

 -- Development Workflow --
1. Make and commit changes to local repository.
2. Inside container nhs_perl:
    /nhs # git pull
    morbo will automatically reload when it detects changes to scripts.
3. Test pages with browser on host at http://localhost:8082/
