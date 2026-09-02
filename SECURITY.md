# Security

## Supported versions

This is a template repository. Only the latest state of the default branch is supported.

## Reporting a vulnerability

Use GitHub private vulnerability reporting on the repository you are actually using:

1. Open the repository's **Security** tab.
2. Select **Report a vulnerability**.

Fork owners must enable private vulnerability reporting in their own repository settings before it can be used. Do not report a fork's vulnerability to the template's upstream repository.

Use a public issue only for non-sensitive problems. Do not include credentials, tokens, private logs, or other secrets.

## Add-on security surface

Reports involving these areas are especially useful:

- AppArmor profiles and their allowed paths, capabilities, and signals
- `map:` volume access
- `privileged`, `full_access`, or `docker_api` options
- Add-on images running on the user's Home Assistant host
