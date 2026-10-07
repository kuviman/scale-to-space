FROM docker.io/library/debian:unstable

RUN apt update && apt install -y \
    libbacktrace-dev \
    libunwind-dev \
    libsdl3-dev \
    libsdl3-mixer-dev \
    libsdl3-image-dev \
    libgl-dev \
    libglew-dev \
    build-essential \
    git \
    just
RUN git clone https://github.com/TinyCC/tinycc && cd tinycc && ./configure && make && make install
