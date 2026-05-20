# python-coverage-action

Run `pytest` with [coverage.py](https://coverage.readthedocs.io/) via
[`pytest-cov`](https://pytest-cov.readthedocs.io/), emit a Cobertura
`coverage.xml` and a JUnit `junit.xml`, and optionally upload the result to
SonarQube/SonarCloud or Codecov.

## Features

- Always generates `coverage.xml` and `junit.xml`.
- Always uploads reports as a workflow artifact.
- Optional SonarQube/SonarCloud upload — only runs when explicitly enabled
  **and** a token is provided.
- Optional Codecov upload — same opt-in model.
- Coverage generation is **decoupled** from external SaaS providers. If
  Sonar/Codecov are disabled, the action still produces the same artifacts.
- Configurable working directory for monorepos.
- Configurable failure behavior when no tests are collected.

## Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `python-version` | Python version to install. | No | `3.12` |
| `pytest-args` | Additional arguments forwarded to pytest. | No | `""` |
| `working-directory` | Directory to run tests from. | No | `.` |
| `artifact-name` | Name of the uploaded artifact bundle. | No | `coverage-reports` |
| `artifact-retention-days` | How long GitHub retains the artifact. | No | `14` |
| `fail-on-no-tests` | Fail the action if pytest collects zero tests. | No | `true` |
| `sonar-enabled` | Enable SonarQube/SonarCloud integration. | No | `false` |
| `sonar-token` | Sonar token (required if `sonar-enabled` is `true`). | No | `""` |
| `sonar-host-url` | SonarQube host URL (empty = SonarCloud). | No | `""` |
| `codecov-enabled` | Enable Codecov integration. | No | `false` |
| `codecov-token` | Codecov token (required for private repos). | No | `""` |

## Outputs

| Name | Description |
| --- | --- |
| `coverage-report-path` | Absolute path to the generated `coverage.xml`. |
| `junit-report-path` | Absolute path to the generated `junit.xml`. |

## Usage

Minimal — generates artifacts and uploads them, nothing else:

```yaml
- uses: actions/checkout@v4
- uses: saumitrapatil/bt-python-custom-action/actions/python-coverage-action@v1
```

With extra pytest args:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-coverage-action@v1
  with:
    pytest-args: "-n auto --maxfail=1 tests/"
```

With SonarCloud:

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0   # Sonar wants full history for blame
- uses: saumitrapatil/bt-python-custom-action/actions/python-coverage-action@v1
  with:
    sonar-enabled: "true"
    sonar-token: ${{ secrets.SONAR_TOKEN }}
```

With self-hosted SonarQube:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-coverage-action@v1
  with:
    sonar-enabled: "true"
    sonar-token: ${{ secrets.SONAR_TOKEN }}
    sonar-host-url: ${{ secrets.SONAR_HOST_URL }}
```

With Codecov:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-coverage-action@v1
  with:
    codecov-enabled: "true"
    codecov-token: ${{ secrets.CODECOV_TOKEN }}
```

## Example workflow

```yaml
name: ci

on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: saumitrapatil/bt-python-custom-action/actions/python-coverage-action@v1
        with:
          python-version: "3.12"
          sonar-enabled: "true"
          sonar-token: ${{ secrets.SONAR_TOKEN }}
          codecov-enabled: "true"
          codecov-token: ${{ secrets.CODECOV_TOKEN }}
```

## Behavior notes

- The action installs `pytest` and `pytest-cov` itself. You do **not** need
  to add them to your project's dependencies.
- If `pyproject.toml` is present, the action attempts to install the project
  with `[test]` or `[dev]` extras, then falls back to a plain `pip install .`.
- `coverage.xml` is written relative to `working-directory`. The action's
  `coverage-report-path` output is absolute.
- The action **always** uploads the coverage artifact bundle on success or
  test failure, so you can inspect coverage even when tests fail.

## Security considerations

- `sonar-token` and `codecov-token` are passed to downstream actions via
  environment variables. They are never echoed by `coverage.sh`.
- The Sonar and Codecov steps only run when both the `*-enabled` flag is
  `"true"` **and** the corresponding token is non-empty. This avoids
  accidental no-op runs that would fail with a confusing error.
- Pin to a commit SHA in security-sensitive consumers.
- The action sets `set -euo pipefail` and quotes every expansion.

## Versioning strategy

This action is versioned alongside the rest of the monorepo. See the
top-level [README](../../README.md#versioning-strategy) for the full strategy.

```yaml
# Pinned (recommended for production):
- uses: saumitrapatil/bt-python-custom-action/actions/python-coverage-action@v1.0.0

# Floating major:
- uses: saumitrapatil/bt-python-custom-action/actions/python-coverage-action@v1
```
