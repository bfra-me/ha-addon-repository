# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.24@sha256:93ef607824e3f27e868f11b10938283a98bf880ed57bcf8eaa81c6c2d521f6f5
FROM ${BUILD_FROM}

# renovate: datasource=github-releases depName=home-assistant/tempio versioning=loose
ARG TEMPIO_VERSION=2024.11.2

ARG BUILD_ARCH

LABEL \
    io.hass.type="addon" \
    io.hass.name="Example add-on" \
    io.hass.description="Example add-on" \
    io.hass.url="https://github.com/bfra-me/ha-addon-repository/tree/main/example" \
    org.opencontainers.image.title="Home Assistant Add-on: Example add-on" \
    org.opencontainers.image.description="Example add-on to use as a blueprint for new add-ons." \
    org.opencontainers.image.licenses="Apache-2.0"

# Execute during the build of the image
RUN \
    curl -sSLf -o /usr/bin/tempio \
    "https://github.com/home-assistant/tempio/releases/download/${TEMPIO_VERSION}/tempio_${BUILD_ARCH}"

# Copy root filesystem
COPY rootfs /
