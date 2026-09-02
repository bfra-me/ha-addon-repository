<!-- https://developers.home-assistant.io/docs/add-ons/presentation#keeping-a-changelog -->

## 1.2.7

- Use an explicit pinned multi-platform base image in the Dockerfile.

## 1.2.6

- Update `tempio` to `2026.07.0`.

## 1.2.5

- Build each architecture on its native runner with composable Home Assistant builder actions.
- Publish the configured generic multi-architecture image manifest without a mutable `latest` alias.

## 1.2.4

- Migrate CI builds from the legacy `home-assistant/builder` action to composable actions.
- Use the generic multi-architecture image name.

## 1.2.3

- Drop `armhf` and `armv7` architecture support. The `home-assistant/builder` tool no longer
  accepts these architecture flags, causing CI builds to fail.

## 1.2.2

- Maintenance updates

## 1.2.1

- Maintenance updates

## 1.2.0

- Add an apparmor profile
- Update to 3.15 base image with s6 v3
- Add a sample script to run as service and constrain in aa profile

## 1.1.0

- Updates

## 1.0.0

- Initial release
