# Home Assistant Add-on Repository Template

This repository can be used as a "blueprint" for add-on development to help you get started.

Add-on documentation: <https://developers.home-assistant.io/docs/add-ons>

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fbfra-me%2Fha-addon-repository)

## Add-ons

This repository contains the following add-ons

### [Example add-on](./example)

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

_Example add-on to use as a blueprint for new add-ons._

Notes to developers after forking or using the github template feature:

- While developing, comment out the 'image' key in 'example/config.yaml' so the supervisor builds the add-on locally.
  - Restore it before pushing your changes.
- When you merge to the 'main' branch of your repository a new build will be triggered.
  - Make sure you adjust the 'version' key in 'example/config.yaml' when you do that.
  - Make sure you update 'example/CHANGELOG.md' when you do that.
  - The first time this runs you might need to adjust the image configuration on github container registry to make it public
  - You may also need to set Settings > Actions > General > Workflow permissions to 'Read and write'
- Adjust the 'image' key in 'example/config.yaml' to `ghcr.io/<your-github-owner>/addon-<slug>`.
  - Keep this image name generic; the workflow derives architecture-specific build images internally.
- Rename the example directory.
  - The 'slug' key in 'example/config.yaml' should match the directory name.
- Adjust all keys/url's that points to 'bfra-me' to now point to your user/fork.
- Share your repository on the [Home Assistant Projects forum](https://community.home-assistant.io/c/projects/9).

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg?style=for-the-badge
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg?style=for-the-badge
