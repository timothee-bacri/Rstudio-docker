FROM rocker/rstudio:latest

LABEL org.opencontainers.image.source=https://github.com/timothee-bacri/Rstudio-docker

ARG CONDA_PATH=/shared/miniconda

# Set dgpsi path version, BUILD ARG
# curl -sSL https://raw.githubusercontent.com/mingdeyu/dgpsi-R/refs/heads/master/R/initi_py.R | grep "env_name *<-" | grep --invert-match "^\s*#" | grep --only-matching --perl-regexp 'dgp.*\d'
ARG DGPSI_FOLDER_NAME

ARG CONDA_ENV_PATH=${CONDA_PATH}/envs/${DGPSI_FOLDER_NAME}

ARG DEBIAN_FRONTEND=noninteractive

# Allow users with user id starting from 500 to login
RUN echo "auth-minimum-user-id=500" | tee -a "/etc/rstudio/rserver.conf"

# Allow GitHub Copilot integration (c.f. https://github.com/rocker-org/rocker-versioned2/issues/826)
# c.f. https://docs.posit.co/ide/user/ide/guide/tools/copilot.html#setup
RUN echo "copilot-enabled=1" | tee -a /etc/rstudio/rsession.conf
RUN cat /etc/rstudio/rsession.conf

# Users can run some apt commands
RUN addgroup rstudio-users

RUN apt-get update && \
    apt-get -y --no-install-recommends install \
    # To download files
    wget \
    libcurl4-openssl-dev \
    # For devtools and dgpsi
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
    # For elliptic
    pari-gp \
    # For sf, terra
    gdal-bin \
    # For keyring
    libsecret-1-dev \
    # For knitr, markdown
    pandoc \
    # Generate SSH key for usage with git
    openssh-client && \
    apt-get -y upgrade && \
    apt-get -y clean && \
    apt-get -y autoremove --purge && \
    rm -rf /var/lib/apt/lists/* /tmp/*

RUN cat /etc/rstudio/rsession.conf

# Miniconda https://docs.anaconda.com/miniconda/
# Miniconda only supports s390x and x86_64 (amd64) and aarch64 (arm64)
# But rocker:rstudio only supports amd64 and arm64
RUN mkdir -p "${CONDA_PATH}"
RUN arch=$(uname -m) && wget "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${arch}.sh" -O "${CONDA_PATH}/miniconda.sh"
RUN bash "${CONDA_PATH}/miniconda.sh" -b -u -p "${CONDA_PATH}"
RUN rm -f "${CONDA_PATH}/miniconda.sh"

RUN cat /etc/rstudio/rsession.conf

COPY DESCRIPTION_* .
# Packages update once in a while. We (arbitrarily) update them by invalidating the cache monthly by updating DESCRIPTION
RUN date +%Y-%m && \
    Rscript -e "install.packages('pak')" && \
    # Rscript -e "pak::pkg_install('github::mingdeyu/dgpsi-R')" && \
    for description_file in DESCRIPTION_*; do \
        echo "NOW WORKING WITH THE DESCRIPTION FILE WITH NAME $description_file" && \
        cp "$description_file" DESCRIPTION && \
        Rscript -e "pak::local_install_dev_deps(upgrade = TRUE)"; \
        rm -f DESCRIPTION "$description_file"; \
    done && \
    rm -rf /tmp/*

RUN cat /etc/rstudio/rsession.conf

# Make conda command available to all
ARG PATH_DOLLAR='$PATH' # do not interpolate $PATH, this is meant to update path in .bashrc
ARG COMMAND_EXPORT_PATH_BASHRC="export PATH=\"${CONDA_PATH}/bin:${PATH_DOLLAR}\""
# $COMMAND_EXPORT_PATH_BASHRC contains: export PATH="<conda_path>/bin:$PATH"
RUN echo "${COMMAND_EXPORT_PATH_BASHRC}" | tee -a "/etc/bash.bashrc"

RUN cat /etc/rstudio/rsession.conf

# Timezone for all users
RUN echo "${TZ}" | tee -a /etc/environment

# Tell all R sessions about it (see details in reticulate:::find_conda())
RUN echo "options(reticulate.conda_binary = '${CONDA_PATH}/bin/conda')" | tee -a "$R_HOME/etc/Rprofile.site"
ENV RETICULATE_CONDA="${CONDA_PATH}/bin/conda"

RUN cat /etc/rstudio/rsession.conf

# Initialize dgpsi, and say yes to all prompts
RUN Rscript -e "readline<-function(prompt) {return('Y')};dgpsi::init_py()"

RUN cat /etc/rstudio/rsession.conf

# Downscaling uses all the magick disk cache -> increase it
# This seems to not work when done before dgpsi::init_py()
# https://stackoverflow.com/questions/31407010/cache-resources-exhausted-imagemagick
RUN sed -E -i 's|  <policy domain="resource" name="disk" value="[0-9]GiB"/>|  <policy domain="resource" name="disk" value="8GiB"/>|' /etc/ImageMagick-*/policy.xml
RUN grep '  <policy domain="resource" name="disk" value=' /etc/ImageMagick-*/policy.xml

RUN cat /etc/rstudio/rsession.conf

# Create users if needed, at runtime
# Run plumber in Exec form (https://docs.docker.com/reference/build-checks/json-args-recommended/)
COPY --chmod=110 docker_startup_manage_users.bash /docker_startup_manage_users.bash

RUN cat /etc/rstudio/rsession.conf

CMD ["bash", "-c", "/docker_startup_manage_users.bash && /init"]
