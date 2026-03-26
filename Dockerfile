FROM ubuntu:22.04

ENV USER build
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install -y software-properties-common

# Set timezone
ENV TZ "Europe/Berlin"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
RUN echo $TZ > /etc/timezone

# Required Packages for the Host Development System
RUN apt-get update && apt-get install --no-install-recommends -y \
    bash-completion \
    build-essential \
    chrpath \
    cpio \
    curl \
    debianutils \
    diffstat \
    file \
    g++-multilib \
    gawk \
    gcc-multilib \
    git-core \
    git-email \
    git-man \
    htop \
    iproute2 \
    iputils-ping \
    jq \
    libcups2-dev \
    liblz4-tool \
    libncurses-dev \
    libssl-dev \
    locales \
    nano \
    openssh-client \
    pylint \
    python3 \
    python3-pexpect \
    python3-pip \
    rsync \
    socat \
    sudo \
    texinfo \
    tmux \
    unzip \
    vim \
    wget \
    xterm \
    xutils-dev \
    xz-utils \
    zip \
    zstd && \
    rm -rf /var/lib/apt/lists/*

# Add kas tool
ARG KAS_VERSION=5.2
RUN pip3 install --upgrade pip && \
    pip3 install --no-input kas${KAS_VERSION:+==$KAS_VERSION}

# Fix error "Please use a locale setting which supports utf-8."
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# make /bin/sh symlink to bash instead of dash
RUN echo "dash dash/sh boolean false" | debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash

# Create a non-root user that will perform the actual build
RUN id $USER 2>/dev/null || useradd --create-home $USER
RUN echo "$USER ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers

USER $USER
RUN sudo chown -R $USER:$USER /home/$USER

WORKDIR /home/$USER

CMD ["/bin/bash"]
