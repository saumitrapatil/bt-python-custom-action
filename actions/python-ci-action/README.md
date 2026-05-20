# python-ci-action

One-step Python CI. This action composes the org's individual actions —
[`python-lint-action`](../python-lint-action/),
[`python-coverage-action`](../python-coverage-action/),
[`trivy-fs-action`](../trivy-fs-action/), and
[`trufflehog-action`](../trufflehog-action/) — behind a single, minimal
interface.

Instead of wiring up four actions in every consumer repository:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-lint-action@v1
- uses: saumitrapatil/bt-python-custom-action/actions/python-coverage-action@v1
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-fs-action@v1
- uses: saumitrapatil/bt-python-custom-action/actions/trufflehog-action@v1
```

consumers write one line:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-ci-action@v1
```

## What it runs

The action runs three stages, in order, in a single job. Each stage is
independently toggleable:

| Stage | Toggle | Composes |
| --- | --- | --- |
| Lint | `run-lint` | `python-lint-action` (Ruff, optional Black/MyPy) |
| Test + coverage | `run-tests` | `python-coverage-action` (pytest, coverage.xml, junit.xml) |
| Security | `run-security` | `trivy-fs-action` (vulns + secrets + Dockerfile/IaC misconfig) and `trufflehog-action` (verified secret scan) |

Because the stages are composite steps in one job, a failure in any stage
fails the action immediately — lint failure short-circuits before tests run.

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| `python-version` | Python version to install. | `3.12` |
| `working-directory` | Directory to lint, test, and scan. | `.` |
| `run-lint` | Run the lint stage. | `true` |
| `run-tests` | Run the test + coverage stage. | `true` |
| `run-security` | Run the security stage. | `true` |
| `run-black` | Also run `black --check` in the lint stage. | `false` |
| `run-mypy` | Also run `mypy` in the lint stage. | `false` |
| `pytest-args` | Extra arguments forwarded to pytest. | `""` |
| `fail-on-no-tests` | Fail if pytest collects no tests. | `true` |
| `codecov-enabled` | Upload coverage to Codecov. | `false` |
| `codecov-token` | Codecov token. | `""` |
| `sonar-enabled` | Upload to SonarQube/SonarCloud. | `false` |
| `sonar-token` | Sonar token. | `""` |
| `trivy-severity` | Severities the Trivy scan reports. | `CRITICAL,HIGH` |
| `trivy-exit-code` | Exit code on Trivy findings (`0` = audit-only). | `1` |
| `upload-sarif` | Upload Trivy SARIF to the Security tab. | `true` |

For finer control than these inputs expose, drop down to the individual
actions — `python-ci-action` is deliberately a curated subset of their
combined surface.

## Outputs

| Name | Description |
| --- | --- |
| `coverage-report-path` | Absolute path to `coverage.xml` (empty if tests skipped). |
| `junit-report-path` | Absolute path to `junit.xml` (empty if tests skipped). |

## Usage

The whole pipeline with defaults:

```yaml
jobs:
  ci:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write   # for the Trivy SARIF upload
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0       # TruffleHog diff scans need history
      - uses: saumitrapatil/bt-python-custom-action/actions/python-ci-action@v1
```

Lint and test only — skip security:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-ci-action@v1
  with:
    run-security: "false"
```

Full strictness with Black, MyPy, and external coverage uploads:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-ci-action@v1
  with:
    run-black: "true"
    run-mypy: "true"
    sonar-enabled: "true"
    sonar-token: ${{ secrets.SONAR_TOKEN }}
    codecov-enabled: "true"
    codecov-token: ${{ secrets.CODECOV_TOKEN }}
```

Security as an audit-only gate (report, never fail the build):

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-ci-action@v1
  with:
    trivy-exit-code: "0"
```

## Required permissions

```yaml
permissions:
  contents: read
  security-events: write   # only when upload-sarif is true (the default)
```

If you set `run-security: "false"` or `upload-sarif: "false"`, the
`security-events: write` permission is not required.

## When to use the individual actions instead

Use `python-ci-action` when you want the standard org pipeline with minimal
YAML. Reach for the individual actions when you need to:

- run stages as **separate jobs** (parallelism, per-stage required checks);
- run a **matrix** of Python versions;
- tune options this action does not expose (e.g. pinned linter versions,
  Trivy `scanners`, custom SARIF categories).

## Versioning strategy

This action is versioned alongside the rest of the monorepo. See the
top-level [README](../../README.md#versioning-strategy).

```yaml
# Pinned (recommended for production):
- uses: saumitrapatil/bt-python-custom-action/actions/python-ci-action@v1.0.0

# Floating major:
- uses: saumitrapatil/bt-python-custom-action/actions/python-ci-action@v1
```
