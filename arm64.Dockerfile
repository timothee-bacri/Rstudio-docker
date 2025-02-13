FROM rocker/rstudio:latest

LABEL org.opencontainers.image.source https://github.com/timothee-bacri/Rstudio-docker

ARG CONDA_PATH=/shared/miniconda

# Set dgpsi path version, BUILD ARG
# curl -sSL https://raw.githubusercontent.com/mingdeyu/dgpsi-R/refs/heads/master/R/initi_py.R | grep "env_name *<-" | grep --invert-match "^\s*#" | grep --only-matching --perl-regexp 'dgp.*\d'
ARG DGPSI_FOLDER_NAME

ARG CONDA_ENV_PATH=${CONDA_PATH}/envs/${DGPSI_FOLDER_NAME}

ARG USERS="bertrand boyun daniel deyu ivis muhammad timothee"
ARG DEFAULT_PASSWORD="orchid"
ARG DEBIAN_FRONTEND=noninteractive

# Miniconda only supports s390x and x86_64 (amd64) and aarch64 (arm64)
# But rocker:rstudio only supports amd64 and arm64
RUN arch=$(uname -p) && \
    if [ "$arch" != "x86_64" -a "$arch" != "aarch64" ]; then \
        echo "Unsupported architecture: $arch"; \
        exit 1; \
    fi

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y --no-install-recommends install \
    libcurl4-openssl-dev \
    # packages (devtools, dgpsi)
    libfontconfig1-dev libxml2-dev libudunits2-dev libssl-dev libproj-dev cmake libgdal-dev libharfbuzz-dev libfribidi-dev \
    # For RRembo, it depends on eaf
    libgsl-dev libglu1-mesa \
    # For dgpsi
    libtiff-dev libjpeg-dev && \
    apt-get -y clean && \
    apt-get -y autoremove --purge && \
    rm -rf /var/lib/apt/lists/*

# Miniconda https://docs.anaconda.com/miniconda/
RUN mkdir -p "${CONDA_PATH}"
RUN arch=$(uname -p) && \
    wget "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${arch}.sh" -O "${CONDA_PATH}/miniconda.sh" && \
    bash "${CONDA_PATH}/miniconda.sh" -b -u -p "${CONDA_PATH}" && \
    rm -f "${CONDA_PATH}/miniconda.sh"

# Install packages while making the image small
COPY DESCRIPTION_timothee DESCRIPTION
# Packages update once in a while. We (arbitrarily) update them by invalidating the cache monthly by updating DESCRIPTION
RUN Rscript -e "install.packages('devtools')"
RUN Rscript -e "devtools::install_github('mingdeyu/dgpsi-R')"
RUN Rscript -e "install.packages('remotes')"
RUN Rscript -e "remotes::install_deps(repos = 'https://cran.rstudio.com')"
RUN rm -f DESCRIPTION

# Users can read and copy files in /shared
RUN addgroup rstudio-users

# Initialize users
RUN for user in ${USERS}; do \
        adduser --disabled-password --gecos "" "${user}" && \
        echo "${user}:${DEFAULT_PASSWORD}" | chpasswd && \
        usermod --append --groups rstudio-users "${user}" && \
        mkdir -p "/shared/${user}" && \
        chown -R "${user}" "/shared/${user}"; \
    done
RUN chgrp -R rstudio-users /shared
RUN chmod -R g+s /shared

# Make conda command available to all
ARG PATH_DOLLAR='$PATH' # do not interpolate $PATH, this is meant to update path in .bashrc
ARG COMMAND_EXPORT_PATH_BASHRC="export PATH=\"${CONDA_PATH}/bin:${PATH_DOLLAR}\""
# $COMMAND_EXPORT_PATH_BASHRC contains: export PATH="<conda_path>/bin:$PATH"
RUN for userpath in /home/*/ /root/; do \
        echo "${COMMAND_EXPORT_PATH_BASHRC}" | tee -a "${userpath}/.bashrc"; \
    done
# Tell all R sessions about it
RUN echo "options(reticulate.conda_binary = '${CONDA_PATH}/bin/conda')" | tee -a "$R_HOME/etc/Rprofile.site"

# Initialize dgpsi, and say yes to all prompts
RUN Rscript -e "readline<-function(prompt) {return('Y')};dgpsi::init_py()"

# Let users install packages, update package list, search
RUN mkdir -p /etc/sudoers.d
RUN echo "User_Alias MYUSERS = ${USERS}" > /etc/sudoers.d/group-rstudio-users
RUN echo "Cmnd_Alias INSTALL = /usr/bin/apt-get install *, /usr/bin/apt install *" >> /etc/sudoers.d/group-rstudio-users
RUN echo "Cmnd_Alias UPDATE = /usr/bin/apt-get update, /usr/bin/apt update" >> /etc/sudoers.d/group-rstudio-users
RUN echo "Cmnd_Alias SEARCH = /usr/bin/apt-get search, /usr/bin/apt search" >> /etc/sudoers.d/group-rstudio-users
RUN echo "MYUSERS ALL = INSTALL, UPDATE, SEARCH" >> /etc/sudoers.d/group-rstudio-users
