# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
FROM ghcr.io/home-assistant/base:3.24@sha256:992dc6a5727b97a30da8dd259b489739299c324407557df540165e2f0dbb7763

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
