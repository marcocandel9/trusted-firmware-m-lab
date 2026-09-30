FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        git \
        curl \
        wget \
        build-essential \
        libssl-dev \
        python3 \
        python3-pip \
        python3-venv \
        cmake \
        make \
        vim \
        qemu-system-arm

ARG ARM_TOOLCHAIN_VERSION=13.3.rel1
RUN curl -fL "https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_TOOLCHAIN_VERSION}/binrel/arm-gnu-toolchain-${ARM_TOOLCHAIN_VERSION}-aarch64-arm-none-eabi.tar.xz" \
        -o /tmp/tc.tar.xz \
    && mkdir -p /opt/arm-toolchain \
    && tar -xJf /tmp/tc.tar.xz -C /opt/arm-toolchain --strip-components=1 \
    && rm /tmp/tc.tar.xz

ENV PATH="/opt/arm-toolchain/bin:$PATH"

RUN git config --system protocol.version 0
RUN git config --system --add safe.directory '*'

WORKDIR /work

CMD ["/bin/bash"]
