FROM px4io/px4-dev-base-jammy

# Add Gazebo Harmonic repository
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    lsb-release \
    && wget https://packages.osrfoundation.org/gazebo.gpg -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" > /etc/apt/sources.list.d/gazebo-stable.list \
    && rm -rf /var/lib/apt/lists/*

# Install Gazebo Harmonic and simulation dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bc \
    dmidecode \
    gz-harmonic \
    libunwind-dev \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libeigen3-dev \
    libimage-exiftool-perl \
    libopencv-dev \
    libxml2-utils \
    pkg-config \
    protobuf-compiler \
    xvfb \
    gdbserver \
    && rm -rf /var/lib/apt/lists/*
