FROM rocker/rstudio:latest

LABEL org.opencontainers.image.source=https://github.com/timothee-bacri/Rstudio-docker

ARG CONDA_PATH=/shared/miniconda

# Set dgpsi path version, BUILD ARG
# curl -sSL https://raw.githubusercontent.com/mingdeyu/dgpsi-R/refs/heads/master/R/initi_py.R | grep "env_name *<-" | grep --invert-match "^\s*#" | grep --only-matching --perl-regexp 'dgp.*\d'
ARG DGPSI_FOLDER_NAME

ARG CONDA_ENV_PATH=${CONDA_PATH}/envs/${DGPSI_FOLDER_NAME}

ARG USERS="dw356 ik354 mh1176 trfb201 jm622 mcm216"
ARG USER_IDS="502 505 503 507 504 506"

ARG DEFAULT_PASSWORD="orchid"
ARG DEBIAN_FRONTEND=noninteractive

# Allow users with user id starting from 500 to login
RUN echo "auth-minimum-user-id=500" | tee -a "/etc/rstudio/rserver.conf"

# Users can run some apt commands
RUN addgroup rstudio-users

# Initialize users
RUN bash -c ' \
        USERS_ARRAY=($USERS); \
        USER_IDS_ARRAY=($USER_IDS); \
        for i in "${!USERS_ARRAY[@]}"; do \
            user="${USERS_ARRAY[i]}" && \
            user_id="${USER_IDS_ARRAY[i]}" && \
            adduser --disabled-password --comment "" --uid "${user_id}" --shell /bin/bash "${user}" && \
            echo "${user}:${DEFAULT_PASSWORD}" | chpasswd && \
            usermod --append --groups rstudio-users "${user}" ; \
        done \
    '

RUN apt-get update && \
    apt-get -y --no-install-recommends install \
    libcurl4-openssl-dev \
    # packages (devtools, dgpsi)
    libfontconfig1-dev libxml2-dev libudunits2-dev libssl-dev libproj-dev cmake libgdal-dev libharfbuzz-dev libfribidi-dev \
    # Specific to arm64
    libgit2-dev \
    # For RRembo, it depends on eaf
    libgsl-dev libglu1-mesa \
    # For dgpsi
    libtiff-dev libjpeg-dev git \
    # needed to install dgpsi via devtools for some reason
    libtool automake \
    # For gifsky
    cargo xz-utils \
    # For convenience
    nano man-db curl cron finger bind9-dnsutils htop \
    # For backend (plumber package)
    libsodium-dev \
    # For magick (downscaling)
    libmagick++-dev gsfonts \
    # For rgl (dependency)
    libgl1-mesa-dev libglu1-mesa-dev \
    # For elliptic (dependency)
    pari-gp \
    # For sf, terra
    gdal-bin \
    # For keyring (dependency)
    libsecret-1-dev \
    # For knitr, markdown
    pandoc \
    # Generate SSH key for usage with git
    openssh-client && \
    apt-get -y upgrade && \
    apt-get -y clean && \
    apt-get -y autoremove --purge && \
    rm -rf /var/lib/apt/lists/* /tmp/*

# Miniconda https://docs.anaconda.com/miniconda/
# Miniconda only supports s390x and x86_64 (amd64) and aarch64 (arm64)
# But rocker:rstudio only supports amd64 and arm64
RUN mkdir -p "${CONDA_PATH}"
RUN arch=$(uname -p) && \
    wget "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${arch}.sh" -O "${CONDA_PATH}/miniconda.sh" && \
    bash "${CONDA_PATH}/miniconda.sh" -b -u -p "${CONDA_PATH}" && \
    rm -f "${CONDA_PATH}/miniconda.sh"

COPY DESCRIPTION_* .
# Packages update once in a while. We (arbitrarily) update them by invalidating the cache monthly by updating DESCRIPTION
RUN date +%Y-%m && \
    Rscript -e "install.packages('pak')" && \
    # Rscript -e "pak::pkg_install('github::mingdeyu/dgpsi-R')" && \
    for description_file in DESCRIPTION_*; do \
        echo "$description_file" && \
        cp $description_file DESCRIPTION && \
        Rscript -e "pak::local_install_dev_deps(upgrade = TRUE)"; \
    done && \
    rm -rf /tmp/*
RUN rm -f DESCRIPTION_*

# Make conda command available to all
ARG PATH_DOLLAR='$PATH' # do not interpolate $PATH, this is meant to update path in .bashrc
ARG COMMAND_EXPORT_PATH_BASHRC="export PATH=\"${CONDA_PATH}/bin:${PATH_DOLLAR}\""
# $COMMAND_EXPORT_PATH_BASHRC contains: export PATH="<conda_path>/bin:$PATH"
RUN echo "${COMMAND_EXPORT_PATH_BASHRC}" | tee -a "/etc/bash.bashrc"

# Tell all R sessions about it (see details in reticulate:::find_conda())
RUN echo "options(reticulate.conda_binary = '${CONDA_PATH}/bin/conda')" | tee -a "$R_HOME/etc/Rprofile.site"
ENV RETICULATE_CONDA="${CONDA_PATH}/bin/conda"

# Initialize dgpsi, and say yes to all prompts
RUN Rscript -e "readline<-function(prompt) {return('Y')};dgpsi::init_py()"

# Downscaling uses all the magick disk cache -> increase it
# This seems to not work when done before dgpsi::init_py()
# https://stackoverflow.com/questions/31407010/cache-resources-exhausted-imagemagick
RUN sed -E -i 's|  <policy domain="resource" name="disk" value="[0-9]GiB"/>|  <policy domain="resource" name="disk" value="8GiB"/>|' /etc/ImageMagick-*/policy.xml
RUN grep '  <policy domain="resource" name="disk" value=' /etc/ImageMagick-*/policy.xml

# Let users install packages, update package list, search
RUN mkdir -p /etc/sudoers.d
RUN bash -c 'echo "User_Alias MYUSERS = ${USERS// /,}" | tee /etc/sudoers.d/group-rstudio-users'
RUN echo "Cmnd_Alias INSTALL = /usr/bin/apt-get install *, /usr/bin/apt install *" >> /etc/sudoers.d/group-rstudio-users
RUN echo "Cmnd_Alias UPDATE = /usr/bin/apt-get update, /usr/bin/apt update" >> /etc/sudoers.d/group-rstudio-users
RUN echo "Cmnd_Alias SEARCH = /usr/bin/apt-get search, /usr/bin/apt search" >> /etc/sudoers.d/group-rstudio-users
RUN echo "MYUSERS ALL = INSTALL, UPDATE, SEARCH" >> /etc/sudoers.d/group-rstudio-users
