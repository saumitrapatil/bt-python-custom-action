# python-lint-action

Lint Python code with [Ruff](https://docs.astral.sh/ruff/), optionally
[Black](https://black.readthedocs.io/) and [MyPy](https://mypy.readthedocs.io/).

## Features

- Ruff linting on every run.
- Optional `black --check` (formatting drift detection — does not modify files).
- Optional `mypy` static type check.
- Detects `requirements.txt` or `pyproject.toml` and installs project
  dependencies before linting, so type-checking sees real symbols.
- Configurable working directory.
- Pinnable linter versions for reproducible CI.

## Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `python-version` | Python version to install. | No | `3.12` |
| `run-black` | Also run `black --check`. | No | `false` |
| `run-mypy` | Also run `mypy`. | No | `false` |
| `working-directory` | Directory to lint from (relative to workspace root). | No | `.` |
| `ruff-version` | Pinned Ruff version (empty = latest). | No | `""` |
| `black-version` | Pinned Black version (empty = latest). | No | `""` |
| `mypy-version` | Pinned MyPy version (empty = latest). | No | `""` |

## Outputs

| Name | Description |
| --- | --- |
| `ruff-exit-code` | Exit code returned by Ruff. `0` on success. |
| `black-exit-code` | Exit code returned by Black, empty if not run. |
| `mypy-exit-code` | Exit code returned by MyPy, empty if not run. |

The job fails if any configured linter exits non-zero, regardless of whether
you read these outputs.

## Usage

Minimal:

```yaml
- uses: actions/checkout@v4
- uses: saumitrapatil/bt-python-custom-action/actions/python-lint-action@v1
```

With Black and MyPy:

```yaml
- uses: actions/checkout@v4
- uses: saumitrapatil/bt-python-custom-action/actions/python-lint-action@v1
  with:
    python-version: "3.12"
    run-black: "true"
    run-mypy: "true"
```

With pinned linter versions for reproducible CI:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-lint-action@v1
  with:
    ruff-version: "0.6.9"
    black-version: "24.10.0"
    mypy-version: "1.13.0"
```

Against a sub-directory (monorepo with one Python package per folder):

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-lint-action@v1
  with:
    working-directory: services/api
```

## Example workflow

```yaml
name: ci

on:
  pull_request:
  push:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: saumitrapatil/bt-python-custom-action/actions/python-lint-action@v1
        with:
          python-version: "3.12"
          run-black: "true"
          run-mypy: "true"
```

## Security considerations

- Third-party actions used internally are pinned to a major version
  (`actions/setup-python@v5`). For supply-chain hardening, fork this action
  into your organization and pin to a commit SHA.
- The script uses `set -euo pipefail` and quotes every expansion.
- No secrets are read or echoed by this action.
- Run on `ubuntu-latest` or a hardened self-hosted runner with restricted
  network egress.

## Versioning strategy

This action is versioned alongside the rest of the monorepo. See the
top-level [README](../../README.md#versioning-strategy) for the full strategy.

Reference an immutable tag for reproducible builds:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-lint-action@v1.0.0
```

…or the floating major tag to receive minor and patch updates automatically:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-lint-action@v1
```
