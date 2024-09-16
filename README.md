# RStudio-Server Docker image for Decision-support tools

## Packages
Packages are listed in `DESCRIPTION`. This allows to reduce the image size slightly compared to `install.packages` and other methods.
Also has the development versions of https://github.com/mingdeyu/dgpsi-R/ and https://github.com/mbinois/RRembo.

## Conda
Miniconda is installed for all users in `/shared/miniconda`, and `dgpsi` is setup in it with `dgpsi::init_py()`.
To make conda in `/shared/miniconda` work in the command line and R easily,
1. `export PATH="/shared/miniconda/bin:${PATH}"` is appended to `~/.bashrc` for all users defined in the Dockerfile
2. `options(reticulate.conda_binary = '/shared/minicond/bin/conda')` is appended to `$R_HOME/etc/Rprofile.site`

Packages and Miniconda make the container size big, but everything about `dgpsi` and `RRembo` is ready.

To make it simpler, `apt install`, `apt search`, `apt update` and their `apt-get` variants are allowed to all users.

## IMPORTANT
- To avoid resetting passwords on every container recreation, bind-mount `/etc/shadow`
- To connect to a GitHub repository easily, bind-mount your SSH keys to `~/.ssh/`
- The default user passwords are "orchid" (without the quotation marks)

## docker-compose.yml
```yaml
services:
  rstudio:
    image: ghcr.io/timothee-bacri/rstudio-docker:main
    container_name: rstudio
    # environment:
      # Default user is rstudio
      # USER: rstudio

      # rstudio's default password is rstudio
      # PASSWORD: rstudio

      # rstudio's default IDs are 1000:1000
      # USERID: 1000
      # GROUPID: 1000

      # Root account is disabled by default
      # ROOT: false # false,true

      # Default umask is 022
      # UMASK: # ${UMASK:=022}

      # By default, authentication is mandatory
      # DISABLE_AUTH: false # false,true

      # By default, shiny is not available
      # https://github.com/rocker-org/rocker-versioned/blob/master/rstudio/add_shiny.sh
      # ADD: none # none,shiny

    # volumes:
      # - /path/to/rstudio-files/home/:/home
      # - /path/to/rstudio-files/etc-shadow:/etc/shadow:ro
    ports:
      - 8787:8787
```
