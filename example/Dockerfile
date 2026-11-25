# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
FROM ghcr.io/home-assistant/base:3.24@sha256:5021aac8a4b7f2a1397e23a9749dfe9f736463ffa471df6b200216c68d530fe6

# renovate: datasource=github-releases depName=home-assistant/tempio versioning=loose
ARG TEMPIO_VERSION=2026.07.0

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
