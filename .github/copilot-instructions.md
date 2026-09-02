# Copilot Instructions

- Treat `AGENTS.md` as the detailed repository guidance. Keep changes within the requested scope.
- Pin every external GitHub Action to a commit SHA and retain a `# vX.Y.Z` or release-version comment.
- Never interpolate `${{ ... }}` directly into a `run:` body. Put the value in the step's `env:` block and quote shell variables.
- Use least-privilege workflow `permissions:`. Pull requests build with read-only contents and never publish.
- Never rename required checks: `Prepare`, `Lint`, `Build`, `Renovate / Renovate`, and `Fro Bot`.
- The current builder uses `home-assistant/builder/actions/{prepare-multi-arch-matrix,build-image,publish-multi-arch-manifest}@4de35182ce1e329181bffcbcc84d33db5e2c7e10 # 2026.06.0`. Do not describe or restore the retired top-level `home-assistant/builder` action.
- `build-image` injects only `BUILD_ARCH` and `BUILD_VERSION`, not `BUILD_FROM`. Use a generic multi-platform base such as `ghcr.io/home-assistant/base:<tag>@sha256:<digest>`; never use a per-architecture `{arch}-base` image.
- Let the builder own `io.hass.arch`, `io.hass.version`, and `org.opencontainers.image.{created,source,version}`. Dockerfiles must provide the remaining required labels and an SPDX `org.opencontainers.image.licenses` value.
- Keep `config.yaml` as the release-version source and match its `version` to the top `## <version>` heading in `CHANGELOG.md`.
- Add-ons are discovered from any top-level directory containing `config.json`, `config.yaml`, or `config.yml`. Do not hardcode `example` or `bfra-me`.
- Do not add `build.yaml`, git-tag releases, GitHub Releases, semantic-release, or changesets.
