FROM ubuntu:22.04

# set default user name 
ARG DOCKER_USER=builder

ARG DEBIAN_FRONTEND=noninteractive

# install yocto dependencies
RUN \
    apt-get update && \
    apt-get install -y build-essential \
    chrpath \
    cpio \
    debianutils \
    diffstat \
    file \
    gawk \
    gcc \
    git \
    iputils-ping \
    libacl1 \
    liblz4-tool \
    locales \
    python3 \
    python3-git \
    python3-jinja2 \
    python3-pexpect \
    python3-pip \
    python3-subunit \
    socat \
    texinfo \
    unzip \
    wget \
    xz-utils \
    zstd

# set locales adn generate required by yocto
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.utf8

RUN apt-get install -y \
    curl \
    net-tools \
    bmap-tools\
    btop\
    python3-newt\
    git\
    git-lfs\
    nano\
    sudo \
    gfortran \
    && rm -rf /var/lib/apt/lists/*

# Create a group and user
RUN addgroup "$DOCKER_USER" && \
    useradd -ms /bin/bash -g $DOCKER_USER -G sudo $DOCKER_USER && \
    echo "${DOCKER_USER}:${DOCKER_USER}" | chpasswd  && \
    echo 'build ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# install gosu
RUN curl -o /usr/local/bin/gosu -sSL "https://github.com/tianon/gosu/releases/download/1.16/gosu-$(dpkg --print-architecture)" && \
    chmod +x /usr/local/bin/gosu

# Set environment variable for the branch
ARG KAS_VERSION="4.7"

# clone and install kas
RUN pip install kas

USER root

RUN rm /usr/bin/sh &&  ln -s /usr/bin/bash /usr/bin/sh

COPY files/entrypoint /
COPY files/bashrc /home/${DOCKER_USER}/.bashrc

RUN chmod 0755 /entrypoint \
 && sed "s/\$DOCKER_USER/$DOCKER_USER/g" -i /entrypoint

ENTRYPOINT ["/entrypoint"]
