# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.20@sha256:f41b6c04af6cb47a048f3e81f11de9bc43af74fc9a01457cdce36369ea0d4f03
FROM ${BUILD_FROM}

# renovate: datasource=github-releases depName=home-assistant/tempio versioning=loose
ARG TEMPIO_VERSION=2021.09.0

ARG BUILD_ARCH

# Execute during the build of the image
RUN \
    curl -sSLf -o /usr/bin/tempio \
    "https://github.com/home-assistant/tempio/releases/download/${TEMPIO_VERSION}/tempio_${BUILD_ARCH}"

# Copy root filesystem
COPY rootfs /
