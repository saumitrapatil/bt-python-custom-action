# bt-python-custom-action

A monorepo of production-grade, reusable [GitHub Actions](https://docs.github.com/actions)
for Python projects. Each action is a composite action that follows GitHub
Marketplace standards and can be consumed independently across repositories.

## Actions

| Action | Purpose |
| --- | --- |
| [python-ci-action](actions/python-ci-action/) | **One-step Python CI** — composes lint + test/coverage + security scanning behind a single `uses:`. Start here. |
| [python-lint-action](actions/python-lint-action/) | Lint Python code with Ruff, optionally Black and MyPy. |
| [python-coverage-action](actions/python-coverage-action/) | Run pytest with coverage, emit `coverage.xml` / `junit.xml`, optionally upload to SonarQube/SonarCloud or Codecov. |
| [trivy-fs-action](actions/trivy-fs-action/) | Scan the repository filesystem with Trivy for vulnerabilities, secrets, and Dockerfile/IaC misconfigurations; upload SARIF to the GitHub Security tab. |
| [trivy-image-action](actions/trivy-image-action/) | Scan a container image with Trivy and upload SARIF results. |
| [trufflehog-action](actions/trufflehog-action/) | Scan the repository for leaked secrets with TruffleHog. |
| [python-build-action](actions/python-build-action/) | Build a Python distribution and optionally a Docker image. |

## Quick start

Most consumers want the whole pipeline. Use the
[`python-ci-action`](actions/python-ci-action/) orchestrator — one step runs
lint, tests + coverage, and security scanning:

```yaml
name: ci

on:
  pull_request:
  push:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: saumitrapatil/bt-python-custom-action/actions/python-ci-action@v1
```

Need finer control — separate jobs, a version matrix, per-action tuning?
Compose the individual actions instead:

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: saumitrapatil/bt-python-custom-action/actions/python-lint-action@v1

  security:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - uses: saumitrapatil/bt-python-custom-action/actions/trivy-fs-action@v1
      - uses: saumitrapatil/bt-python-custom-action/actions/trufflehog-action@v1
```

See [`examples/`](examples/) for runnable consumer workflows.

## Design principles

- **Composite first.** Every action is a composite action. Docker actions are
  used only when no composite alternative exists.
- **SHA-pinned dependencies.** Every third-party action is pinned to a full
  commit SHA with a human-readable version comment, and
  [Dependabot](.github/dependabot.yml) keeps those pins current. See
  [Security considerations](#security-considerations).
- **Optional integrations are opt-in.** Coverage uploads to SonarQube and
  Codecov only run when the consumer explicitly enables them and provides
  a token.
- **Fail loudly.** Scripts use `set -euo pipefail`. Lint, coverage, and
  secret-scan failures fail the job by default.
- **Secrets stay secret.** Tokens are read as inputs and forwarded via
  environment variables to downstream actions. They are never echoed.

## Repository layout

```text
bt-python-custom-action/
├── .github/
│   ├── dependabot.yml        # Keeps third-party action SHAs current
│   └── workflows/            # CI for this repo
│       ├── test-actions.yml  # Exercises every action on PR/push
│       └── release.yml       # Tags releases and moves the floating major tag
├── actions/                  # One subdirectory per published action
│   ├── python-ci-action/     # Orchestrator — composes the actions below
│   ├── python-lint-action/
│   ├── python-coverage-action/
│   ├── trivy-fs-action/
│   ├── trivy-image-action/
│   ├── trufflehog-action/
│   └── python-build-action/
├── examples/                 # Runnable consumer workflows
│   ├── basic-python-app/
│   └── docker-python-app/
├── LICENSE
├── README.md
└── CONTRIBUTING.md
```

## Versioning strategy

Actions in this monorepo share a single semver line. Releases follow
[Semantic Versioning 2.0.0](https://semver.org).

- `v1.0.0`, `v1.1.0`, `v1.2.3` — immutable, pinned tags. Recommended for
  production consumers who want reproducible builds.
- `v1` — a floating tag that always points at the latest `v1.x.y` release.
  Convenient for consumers who want patch and minor updates automatically.
- `main` — bleeding edge. **Not** recommended for production consumers.

The release workflow at [`.github/workflows/release.yml`](.github/workflows/release.yml)
publishes both the pinned tag and updates the floating major tag.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for release procedure.

## Security considerations

- **SHA-pinned supply chain.** Every third-party action this library calls
  is pinned to a full 40-character commit SHA, with the human-readable
  version in a trailing comment:

  ```yaml
  - uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065 # v5.6.0
  ```

  A mutable tag like `@v5` can be silently repointed by an attacker who
  compromises the upstream repo; a commit SHA cannot.
  [`.github/dependabot.yml`](.github/dependabot.yml) raises grouped weekly
  PRs to advance these pins as upstream releases land.
- **Pinning this library.** Consumers should likewise pin to a SHA or an
  immutable `v1.x.y` tag — see [Versioning strategy](#versioning-strategy).
- **Minimal permissions.** Each example workflow declares the least
  permissions it needs. Security-scan jobs require `security-events: write`
  to upload SARIF.
- **Secret hygiene.** Pass tokens via repository or organization secrets.
  Never hard-code tokens in workflow files.

## Marketplace publishing

GitHub Marketplace requires that the action lives at the repository root.
This monorepo hosts seven actions under `actions/`, so each one is consumed by
**path reference** rather than published to Marketplace from this repo.

To publish an individual action to the Marketplace, fork or split it into a
dedicated repository whose root contains the action's `action.yml`, then
publish from that repo. The release workflow in this monorepo is structured
to make that split straightforward — see [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

[MIT](LICENSE).
