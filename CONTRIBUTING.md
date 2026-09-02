# Contributing

## Add-on layout

CI discovers add-ons dynamically. Any top-level directory containing exactly one supported config file is an add-on:

- `config.yaml`
- `config.yml`
- `config.json`

Do not add workflow logic that depends on a directory named `example`.

## Release metadata

Changes under an add-on directory require a release unless the changed path is the add-on root's `README.md`, `DOCS.md`, `CHANGELOG.md`, `icon.png`, or `logo.png`.

For every release-affecting change:

1. Bump `version` in the add-on's config file.
2. Add a matching top `## <version>` section to that add-on's `CHANGELOG.md`.

The Supervisor resolves the image tag from `config.yaml`. Publishing a changed image under the existing version leaves installed add-ons pointing at the old image.

Run both checks before pushing:

```sh
bash .github/scripts/release-integrity.sh
bash .github/scripts/release-integrity-test.sh
```

## Commits

Use Conventional Commits with a scope:

```text
feat(ci): add a validation check
fix(example): correct the service command
chore(deps): update the pinned action
```

## Local checks

The repository uses Node.js `22.11.0` and Python `3.13.13`, as pinned in `.tool-versions`.

There is no `package.json` and no local npm script. Run the tools directly:

```sh
npx prettier@3.8.3 --check CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md .github/PULL_REQUEST_TEMPLATE.md AGENTS.md
npx markdownlint-cli2 CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md .github/PULL_REQUEST_TEMPLATE.md AGENTS.md
pre-commit run --all-files
```

All checks configured by the repository must pass:

| Required check        |
| --------------------- |
| `Prepare`             |
| `Lint`                |
| `Build`               |
| `Actionlint`          |
| `Hadolint`            |
| `Zizmor`              |
| `Renovate / Renovate` |
| `Fro Bot`             |

## Workflow changes

Pin every external GitHub Action to a commit SHA and retain its version comment. Keep workflow permissions least-privileged. Pull requests must not publish packages.
