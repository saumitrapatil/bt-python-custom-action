# Contributing

Thanks for helping improve this monorepo of reusable GitHub Actions.

## Local development

Every action is a composite action backed by a shell script in `scripts/`.
You can iterate on a script locally, then exercise it end-to-end via the
CI workflow at [`.github/workflows/test-actions.yml`](.github/workflows/test-actions.yml).

### Prerequisites

- `bash` (the scripts target `/usr/bin/env bash`)
- `shellcheck` — `apt install shellcheck` / `brew install shellcheck`
- `yamllint` — `pip install yamllint` (optional but recommended)
- `act` — for running workflows locally, `brew install act` (optional)

### Linting your changes locally

```bash
# Shell scripts
find actions -name "*.sh" -print0 | xargs -0 shellcheck

# YAML
yamllint actions .github examples
```

## Adding a new action

1. Create `actions/<name>/` with `action.yml`, `README.md`, and `scripts/`.
2. Prefer a composite action. Reach for a Docker action only when there
   is no equivalent composite path.
3. Pin every third-party action you reference to a full commit SHA with a
   trailing version comment (e.g.
   `actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065 # v5.6.0`).
   Dependabot ([`.github/dependabot.yml`](.github/dependabot.yml)) keeps these
   pins current. First-party actions in this monorepo are referenced at `@v1`.
4. Update [`README.md`](README.md) and the test workflow
   [`.github/workflows/test-actions.yml`](.github/workflows/test-actions.yml)
   to exercise the new action.

### Action conventions

- `action.yml` must include `name`, `description`, `author`, `branding`,
  `inputs`, `outputs`, and a composite `runs:` block.
- Shell scripts must start with:

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  ```

- Logs use the helpers in each script (`log_info`, `log_warn`, `log_error`)
  for a consistent format.
- Never echo secret values. When you must reference a token, read it from
  an environment variable, not an argument.

## Commit message style

Use [Conventional Commits](https://www.conventionalcommits.org):

```text
feat(python-lint-action): add ruff format check
fix(trivy-fs-action): correct SARIF upload condition
docs(readme): clarify pinning recommendation
```

The commit type drives the next semver bump:

| Commit type | Bump |
| --- | --- |
| `fix:` | patch |
| `feat:` | minor |
| `feat!:` or `BREAKING CHANGE:` footer | major |

## Release procedure

Releases are cut from the `main` branch.

1. Open a PR with your changes. CI must be green.
2. Merge the PR.
3. Trigger the release workflow at
   [`.github/workflows/release.yml`](.github/workflows/release.yml) via the
   `workflow_dispatch` UI, supplying the next semver version
   (e.g. `1.2.0`).
4. The workflow will:
   - Verify the tag does not yet exist.
   - Create the immutable tag `v1.2.0`.
   - Force-update the floating major tag (`v1`) to the same commit.
   - Publish a GitHub Release with auto-generated notes.

### Versioning

Actions in this monorepo share a single semver line. The release workflow
maintains two tags per release:

- `v1.2.0` — immutable. Recommended for reproducible production builds.
- `v1` — floating. Always points at the latest `v1.x.y` release.

Consumers choose their pinning strategy.

## Publishing an individual action to GitHub Marketplace

The GitHub Marketplace requires the published action to live at the root of
its repository. To split an action out:

1. Create a new repository for the action.
2. Copy `actions/<name>/action.yml`, `actions/<name>/README.md`, and
   `actions/<name>/scripts/` into the new repo's root.
3. Adjust any path references in the action's script (none of the actions
   here depend on monorepo-relative paths, so this is usually a no-op).
4. Tag and publish from the new repo. Submit to the Marketplace from the
   release UI.

## Reporting issues

Open an issue with:

- Which action you were using and its pinned version.
- A minimal `.github/workflows/ci.yml` that reproduces the problem.
- The relevant action log output (redact tokens).

## Code of conduct

Be kind. Assume good faith. Review before you ship.
