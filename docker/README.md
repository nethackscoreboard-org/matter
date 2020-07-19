### Docker setup instructions

After pulling the repository, follow these steps to make the NHS run in a Docker environment. It is assumed that you already run [Docker Desktop](https://www.docker.com/products/docker-desktop) or something comparable for your OS.

1. Create the images and run the containers: `docker-compose up -d`. 
2. Enter the 'nhs_perl'-container: `docker exec -it nhs_perl /bin/sh`. 
3. The perl scripts and enviroment is in the '/nhs' folder: `cd /nhs`.
4. Create the config files for the perl scripts: `./create_config.sh`
5. Run the feeder script. Pulling large xlogfiles from e.g. NAO takes a lot of time, so i recommend to only pull from hdf for now: `perl ./nhdb-feeder.pl --server=hdf`
6. Run the stats script, which generates the HTML files. The generated files are reflected in the 'html/' folder on the host. `perl ./nhdb-stats.pl` 
7. Call the generated pages from the browser from the url `localhost:8082/index.html`.