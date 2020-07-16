### Docker setup instructions

After pulling the repository, follow these steps to make the NHS run in a Docker environment. It is assumed that you already run [Docker Desktop](https://www.docker.com/products/docker-desktop) or something comparable for your OS.

1. Create the images and run the containers: `docker-compose up -d`. 
2. Enter the 'nhs_perl'-container: `docker exec -it nhs_perl /bin/sh`. 
3. The perl scripts and enviroment is in the '/nhs' folder: `cd /nhs`.
4. Run the feeder script. Pulling large xlogfiles from e.g. NAO takes a lot of time, so i recommend to only pull from hdf for now: `./nhs-feeder.pl --server=hdf`
5. Run the stats script, which generates the HTML files. The generated files are reflected in the 'html/' folder on the host. `./nhs-stats.pl` 
6. Call the generated pages from the browser from the url `localhost/index.html`.