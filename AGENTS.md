# Agent Instructions

This file has two deliberately separate audiences. Apply only the part that matches the repository you are editing.

## Part I — Maintaining this template

### Overview — template

`bfra-me/ha-addon-repository` is a public GitHub template for Home Assistant add-on repositories. Changes here propagate to repositories created from the template, so keep everything generic and free of repository-specific assumptions.

### Directory structure — template

| Path                          | Purpose                                                       |
| ----------------------------- | ------------------------------------------------------------- |
| `.github/workflows/main.yaml` | Discover add-ons; lint, build, publish, and verify manifests. |
| `.github/settings.yml`        | Repository and `main` branch settings as code.                |
| `.github/renovate.json5`      | Renovate presets and dependency rules.                        |
| `repository.yaml`             | Home Assistant repository metadata.                           |
| `example/`                    | Sample add-on used as a blueprint.                            |
| `.prettierrc.yaml`            | Prettier configuration.                                       |
| `.markdownlint-cli2.yaml`     | Markdownlint configuration.                                   |
| `.pre-commit-config.yaml`     | Pre-commit hooks.                                             |
| `.tool-versions`              | Node.js and Python versions.                                  |
| `.devcontainer.json`          | Home Assistant add-on development container.                  |

### Task-to-location lookup — template

| Task                                                       | Location                                                                 |
| ---------------------------------------------------------- | ------------------------------------------------------------------------ |
| Change discovery, matrices, linting, builds, or publishing | `.github/workflows/main.yaml`                                            |
| Change required checks or branch protection                | `.github/settings.yml`                                                   |
| Change dependency update behavior                          | `.github/renovate.json5`                                                 |
| Change repository metadata                                 | `repository.yaml`                                                        |
| Change the sample add-on                                   | `example/`                                                               |
| Change contributor or agent guidance                       | `AGENTS.md`, `.github/copilot-instructions.md`                           |
| Change formatting or hook configuration                    | `.prettierrc.yaml`, `.markdownlint-cli2.yaml`, `.pre-commit-config.yaml` |

### Conventions — template

- Keep add-on discovery dynamic. A top-level directory containing `config.json`, `config.yaml`, or `config.yml` is an add-on; do not hardcode `example`.
- Use the composable Home Assistant builder actions at the pinned `4de35182ce1e329181bffcbcc84d33db5e2c7e10` ref with the `# 2026.06.0` comment. Do not restore the retired top-level `home-assistant/builder` action.
- `build-image` injects only `BUILD_ARCH` and `BUILD_VERSION`. Add-on Dockerfiles must use a generic multi-platform base such as `ghcr.io/home-assistant/base:<tag>@sha256:<digest>`, never a per-architecture `{arch}-base` image. A per-architecture base can silently put the wrong architecture inside another tag.
- `build-image` supplies and overrides `io.hass.arch`, `io.hass.version`, and `org.opencontainers.image.{created,source,version}`. Dockerfiles supply `io.hass.{type,name,description,url}` and `org.opencontainers.image.{title,description,licenses}`. Set `io.hass.type` to `addon`; use an SPDX identifier for `licenses`.
- Build each architecture on its native runner: `ubuntu-24.04` for `amd64` and `ubuntu-24.04-arm` for `aarch64`.
- Keep building and publishing separate. Pull requests build with `contents: read` and do not push. Publishing uses `packages: write` and `id-token: write` on the default branch. Cosign signing is enabled and requires `id-token: write`.
- Do not rename the required `main` checks: `Prepare`, `Lint`, `Build`, `Renovate / Renovate`, and `Fro Bot`. Branch protection uses strict checks, enforced admins, and one approving review.
- `config.yaml` is the sole release-version source. Its `version` must equal the top `## <version>` heading in the add-on's `CHANGELOG.md`. Do not add git tags, GitHub Releases, semantic-release, or changesets.
- Pin every external action to a commit SHA and retain a version comment. Use Conventional Commits with scopes, such as `feat(ci):`, `fix(example):`, and `chore(deps):`.
- Keep settings as code in `.github/settings.yml` and dependency policy in `.github/renovate.json5`.
- Follow the repository tooling: Node.js `22.11.0`, Python `3.13.13`, Prettier `3.8.3`, markdownlint-cli2, and pre-commit. There is no `package.json` or Node package.

### Anti-patterns — template

- Do not use a per-architecture base image in an add-on Dockerfile.
- Do not interpolate `${{ ... }}` directly into a `run:` body. Pass GitHub values through the step's `env:` block.
- Do not grant broad workflow permissions or make pull requests publish packages.
- Do not rename required-check jobs.
- Do not document `build.yaml` or the retired legacy builder action.
- Do not require root-level `DOCS.md`, `CHANGELOG.md`, or `translations/`; those belong inside an add-on directory when needed.
- Do not hardcode `example` or `bfra-me` in workflow logic or reusable contributor instructions.

### Commands — template

Run the checks from the repository root:

```sh
npx prettier@3.8.3 --check AGENTS.md .github/copilot-instructions.md README.md
npx markdownlint-cli2 AGENTS.md .github/copilot-instructions.md README.md
git diff --check
```

The workflow is the build and publish interface; do not invent local npm scripts.

### Notes — template

- `.github/settings.yml` application is intermittently failing; see issue #569 and the upstream blocker `bfra-me/.github#2667`. Branch protection may need to be applied by hand until that lands.

---

## Part II — Working in a repository created from this template

### Overview — created repository

After creating a repository from this template, replace the sample identity and treat each top-level add-on directory as independently discoverable by CI.

Fork owners must personalize `SECURITY.md` and `CODE_OF_CONDUCT.md`; review `CONTRIBUTING.md`, `.github/ISSUE_TEMPLATE/bug_report.yml`, `.github/ISSUE_TEMPLATE/feature_request.yml`, `.github/ISSUE_TEMPLATE/config.yml`, and `.github/PULL_REQUEST_TEMPLATE.md` for project-specific details.

### Directory structure — created repository

| Path                   | Purpose                                                                                       |
| ---------------------- | --------------------------------------------------------------------------------------------- |
| `repository.yaml`      | Your repository name, URL, and maintainer.                                                    |
| `<addon>/config.yaml`  | Add-on name, slug, version, architectures, and GHCR image.                                    |
| `<addon>/Dockerfile`   | Generic multi-platform base, build steps, and required labels.                                |
| `<addon>/CHANGELOG.md` | Release entries keyed by the add-on version.                                                  |
| `<addon>/`             | Optional `DOCS.md`, translations, AppArmor profile, root filesystem, and presentation assets. |

### Task-to-location lookup — created repository

| Task                             | Location                                                                                         |
| -------------------------------- | ------------------------------------------------------------------------------------------------ |
| Rename the repository identity   | `repository.yaml`                                                                                |
| Rename the sample add-on         | Rename `example/`, then update its `config.yaml`, Dockerfile labels, URLs, and documentation.    |
| Add another add-on               | Create another top-level directory containing `config.yaml`, `Dockerfile`, and its add-on files. |
| Change an add-on release         | `<addon>/config.yaml` and the matching `<addon>/CHANGELOG.md` entry.                             |
| Change the published image owner | `<addon>/config.yaml` `image` value and related repository URLs.                                 |

### Conventions — created repository

- Update `repository.yaml` `name`, `url`, and `maintainer` after templating.
- Rename `example/` to the add-on directory you want. Set `config.yaml` `slug` to that directory name and update `config.yaml` `name` and `image`.
- Use `ghcr.io/<github-owner>/addon-<slug>` as the configured image name. The workflow derives architecture-specific build images internally; do not add an architecture prefix to this value.
- Update `bfra-me` and sample URLs in repository metadata, add-on configuration, Dockerfile labels, and documentation to your owner and repository.
- Add a second add-on as another top-level directory with a supported config filename. CI discovers it automatically; no workflow edit should be needed.
- Change an add-on's `config.yaml` `version` and its top `CHANGELOG.md` heading together. The values must match exactly.
- Keep the Dockerfile base generic: `ghcr.io/home-assistant/base:<tag>@sha256:<digest>`. `BUILD_FROM` is not injected by `build-image`; only `BUILD_ARCH` and `BUILD_VERSION` are.

### Anti-patterns — created repository

- Do not use `{arch}-base` in `FROM` or configured image names.
- Do not add `build.yaml`, git-tag releases, GitHub Releases, semantic-release, or changesets for add-on versioning.
- Do not make the workflow depend on a directory named `example`.
- Do not bump `config.yaml` without the matching changelog heading.
- Do not put GitHub expression interpolation directly in shell source; use `env:`.

### Commands — created repository

From the repository root, validate the documentation and changed files with the commands in Part I. Builds and publishing run through `.github/workflows/main.yaml` on GitHub Actions.

### Notes — created repository

- The first published GHCR package may need its visibility adjusted before Home Assistant can pull it.
- The `.github/settings.yml` sync issue described in Part I can also affect repositories created from this template.
