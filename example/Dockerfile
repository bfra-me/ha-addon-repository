# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.22@sha256:4bb7a73f643f07416573cb892396a76e2663bc7ac127d475f1f3a0b950a58e15
FROM ${BUILD_FROM}

# renovate: datasource=github-releases depName=home-assistant/tempio versioning=loose
ARG TEMPIO_VERSION=2024.11.2

ARG BUILD_ARCH

# Execute during the build of the image
RUN \
    curl -sSLf -o /usr/bin/tempio \
    "https://github.com/home-assistant/tempio/releases/download/${TEMPIO_VERSION}/tempio_${BUILD_ARCH}"

# Copy root filesystem
COPY rootfs /
