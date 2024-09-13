FROM rocker/rstudio:latest

ARG CONDA_PATH=/shared/miniconda
ARG CONDA_ENV_PATH=/shared/miniconda3/envs/dgp_si_R_2_4_0_9000
ARG PATH=$CONDA_ENV_PATH/bin:$PATH

# Users can read and copy files in /shared
RUN addgroup rstudio-users

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y clean && \
    apt-get -y autoremove --purge

RUN apt-get -y --no-install-recommends install libcurl4-openssl-dev
RUN apt-get -y --no-install-recommends install libfontconfig1-dev
RUN apt-get -y --no-install-recommends install libxml2-dev
RUN apt-get -y --no-install-recommends install libudunits2-dev
RUN apt-get -y --no-install-recommends install libssl-dev
RUN apt-get -y --no-install-recommends install libfontconfig1-dev
RUN apt-get -y --no-install-recommends install libproj-dev
RUN apt-get -y --no-install-recommends install cmake
RUN apt-get -y --no-install-recommends install libgdal-dev
RUN apt-get -y --no-install-recommends install libharfbuzz-dev
RUN apt-get -y --no-install-recommends install libfribidi-dev

# For RRembo -> eaf
RUN apt-get -y --no-install-recommends install libgsl-dev libglu1-mesa

# For dgpsi
RUN apt-get -y --no-install-recommends install libtiff-dev libjpeg-dev
RUN arch=$(uname -p) && \
    if [ "$arch" != "s390x" -a "$arch" != "x86_64" -a "$arch" != "aarch64" ]; then \
        echo "Unsupported architecture: $arch"; \
        exit 1; \
    fi
# Need conda -> install miniconda https://docs.anaconda.com/miniconda/
RUN mkdir -p "${CONDA_PATH}"
RUN arch=$(uname -p) && wget "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${arch}.sh" -O "${CONDA_PATH}/miniconda.sh"
RUN ls -alh "${CONDA_PATH}"
RUN bash "${CONDA_PATH}/miniconda.sh -b -u -p ${CONDA_PATH}"
RUN rm -f "${CONDA_PATH}/miniconda.sh"

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y clean && \
    apt-get -y autoremove --purge

# Install packages while making the image small
# RUN Rscript -e "install.packages('remotes', lib = normalizePath(Sys.getenv('R_LIBS_USER')), repos = 'https://cran.rstudio.com/')"
RUN Rscript -e "install.packages('remotes', repos = 'https://cran.rstudio.com')"
COPY DESCRIPTION .
RUN Rscript -e "remotes::install_deps(repos = 'https://cran.rstudio.com')"
RUN Rscript -e "devtools::install_github('mingdeyu/dgpsi-R')"
RUN Rscript -e "devtools::install_github('mbinois/RRembo')"

# RUN useradd \
#     --create-home \
#     --home-dir /home/timothee \
#     --shell /bin/bash \
#     --uid 2001 \
#     --gid rstudio-users \
#     # --password `perl -e 'print crypt("pass", "salt")'` \
#     # --password `perl -e 'print crypt("orchid config", "sj43ip")'` \
#     --password "sjFFjJImAEaTo" \
#     timothee
RUN adduser timothee
RUN echo "timothee:orchid config" | chpasswd
RUN usermod --append --groups rstudio-users timothee

# RUN useradd \
#     --create-home \
#     --home-dir /home/ivis \
#     --shell /bin/bash \
#     --uid 2002 \
#     --gid rstudio-users \
#     --password "sjFFjJImAEaTo" \
#     ivis
RUN adduser ivis
RUN echo "ivis:orchid config" | chpasswd
RUN usermod --append --groups rstudio-users ivis

# RUN useradd \
#     --create-home \
#     --home-dir /home/muhammad \
#     --shell /bin/bash \
#     --uid 2003 \
#     --gid rstudio-users \
#     --password "sjFFjJImAEaTo" \
#     muhammad
RUN adduser muhammad
RUN echo "muhammad:orchid config" | chpasswd
RUN usermod --append --groups rstudio-users muhammad

# RUN useradd \
#     --create-home \
#     --home-dir /home/boyun \
#     --shell /bin/bash \
#     --uid 2004 \
#     --gid rstudio-users \
#     --password "sjFFjJImAEaTo" \
#     boyun
RUN adduser boyun
RUN echo "boyun:orchid config" | chpasswd
RUN usermod --append --groups rstudio-users boyun

# RUN useradd \
#     --create-home \
#     --home-dir /home/bertrand \
#     --shell /bin/bash \
#     --uid 2005 \
#     --gid rstudio-users \
#     --password "sjFFjJImAEaTo" \
#     bertrand
RUN adduser bertrand
RUN echo "bertrand:orchid config" | chpasswd
RUN usermod --append --groups rstudio-users bertrand

# RUN echo "ivis:iamivis" | chpasswd

RUN mkdir -p /shared/timothee /shared/ivis /shared/muhammad /shared/boyun /shared/bertrand
RUN chgrp -R rstudio-users /shared
RUN chmod -R g+s /shared

RUN chown -R timothee /shared/timothee
RUN chown -R ivis /shared/ivis
RUN chown -R muhammad /shared/muhammad
RUN chown -R boyun /shared/boyun
RUN chown -R bertrand /shared/bertrand

VOLUME /shared/timothee /shared/ivis /shared/muhammad /shared/boyun /shared/bertrand
VOLUME /home/timothee /home/ivis /home/muhammad /home/boyun /home/bertrand


# make conda command available to all
RUN for userpath in /home/*/ /root/; do \
        echo 'export PATH="${CONDA_PATH}/bin:$PATH"' | tee -a "${userpath}/.bashrc"; \
    done
# tell all Rstudio sessions about it
RUN echo "options(reticulate.conda_binary = '${CONDA_PATH}/bin/conda')" | tee -a "$R_HOME/etc/Rprofile.site"
# Initialize dgpsi, and say yes to all prompts
RUN Rscript -e "readline<-function(prompt) {return('Y')};dgpsi::init_py()"

RUN ls -alhR "${CONDA_PATH}"

RUN apt-get install -y sudo nano
RUN mkdir -p /etc/sudoers.d

# RUN echo "%rstudio-users ALL=(ALL) /usr/bin/apt-get install *" > /etc/sudoers.d/group-rstudio-users
# RUN echo "%rstudio-users ALL=(ALL) /usr/bin/apt install *" >> /etc/sudoers.d/group-rstudio-users
# RUN echo "%rstudio-users ALL=(ALL) /usr/bin/apt-get update" >> /etc/sudoers.d/group-rstudio-users
# RUN echo "%rstudio-users ALL=(ALL) /usr/bin/apt update" >> /etc/sudoers.d/group-rstudio-users
# RUN echo "%rstudio-users ALL=(ALL) /usr/bin/apt-get search" >> /etc/sudoers.d/group-rstudio-users
# RUN echo "%rstudio-users ALL=(ALL) /usr/bin/apt search" >> /etc/sudoers.d/group-rstudio-users

# Let users install packages, update package list, search
RUN echo "User_Alias MYUSERS = timothee, ivis, muhammad, boyun, bertrand" > /etc/sudoers.d/group-rstudio-users
RUN echo "Cmnd_Alias INSTALL = /usr/bin/apt-get install *, /usr/bin/apt install *" >> /etc/sudoers.d/group-rstudio-users
RUN echo "Cmnd_Alias UPDATE = /usr/bin/apt-get update, /usr/bin/apt update" >> /etc/sudoers.d/group-rstudio-users
RUN echo "Cmnd_Alias SEARCH = /usr/bin/apt-get search, /usr/bin/apt search" >> /etc/sudoers.d/group-rstudio-users

RUN echo "MYUSERS ALL = INSTALL, UPDATE, SEARCH" >> /etc/sudoers.d/group-rstudio-users
# RUN echo "%rstudio-users ALL = INSTALL, UPDATE, SEARCH" >> /etc/sudoers.d/group-rstudio-users