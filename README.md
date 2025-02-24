# RStudio-Server Docker image for Decision-support tools

## Packages
Packages are listed in `DESCRIPTION_*` files. This allows to reduce the image size slightly compared to `install.packages` and other methods.
Also has the development versions of https://github.com/mingdeyu/dgpsi-R/ and https://github.com/mbinois/RRembo.

`dgpsi::init_py()` is done in the image to avoid taking time for users.

## Conda
Miniconda is installed for all users in `/shared/miniconda`.
To make conda in `/shared/miniconda` work in the command line and R easily,
1. `export PATH="/shared/miniconda/bin:${PATH}"` is appended to `~/.bashrc` for all users defined in the Dockerfile
2. `options(reticulate.conda_binary = '/shared/minicond/bin/conda')` is appended to `$R_HOME/etc/Rprofile.site`

Packages and Miniconda make the container size big, but everything about `dgpsi` and `RRembo` is ready.

To make it simpler, `apt install`, `apt search`, `apt update` and their `apt-get` variants are allowed to all users.

## IMPORTANT
- Pick between the `amd64` and `arm64` images
- To avoid resetting passwords on every container recreation, bind-mount `/etc` into a named volume
- To connect to a GitHub repository easily, bind-mount your SSH keys to `~/.ssh/`
- The default user passwords are "orchid" (without the quotation marks)

## docker-compose.yml
Adapt it to your machine and needs, the comments in it are worth reading.
