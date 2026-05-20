# python-build-action

Build a Python distribution (`sdist` + `wheel`) using PEP 517, and optionally
build and push a Docker image in the same step.

This action provides two independent capabilities, each gated by its own
boolean input:

1. **Python build** (`build-python: "true"` by default) — auto-detects the
   project's PEP 517 build backend (setuptools, hatchling, poetry, flit,
   pdm), installs PyPA `build`, and produces `dist/*.tar.gz` and
   `dist/*.whl`. Artifacts are uploaded automatically.
2. **Docker build** (`build-docker: "false"` by default) — composes
   `docker/setup-buildx-action`, `docker/login-action`, and
   `docker/build-push-action` with cache-from/to wired to the GitHub
   Actions cache by default.

You can enable one, the other, or both.

## Features

- Detects the build backend from `pyproject.toml` and exposes it as an output.
- Falls back to `setup.py` / `setup.cfg` when `pyproject.toml` is absent.
- Cleans stale `dist/` between builds for reproducible artifact uploads.
- Optional multi-platform Docker build with Buildx.
- Optional registry login — runs only when registry + username + password
  are all provided.
- GitHub Actions cache wired in by default for fast Docker rebuilds.

## Inputs

### General

| Name | Description | Default |
| --- | --- | --- |
| `python-version` | Python version to install. | `3.12` |
| `working-directory` | Project directory. | `.` |

### Python build

| Name | Description | Default |
| --- | --- | --- |
| `build-python` | Enable the Python build step. | `true` |
| `build-tool-version` | Pinned PyPA `build` version (empty = latest). | `""` |
| `python-artifact-name` | Name of the uploaded artifact. | `python-dist` |
| `artifact-retention-days` | Retention for uploaded artifacts. | `14` |

### Docker build

| Name | Description | Default |
| --- | --- | --- |
| `build-docker` | Enable the Docker build step. | `false` |
| `docker-context` | Build context. | `.` |
| `docker-file` | Dockerfile path. | `Dockerfile` |
| `docker-tags` | Newline-separated tags. | `""` |
| `docker-platforms` | Comma-separated platforms. | `linux/amd64` |
| `docker-push` | Push to registry. | `false` |
| `docker-load` | Load image into local daemon. | `false` |
| `docker-registry` | Registry hostname for login. | `""` |
| `docker-username` | Registry username. | `""` |
| `docker-password` | Registry password/token. | `""` |
| `docker-build-args` | Newline-separated build args. | `""` |
| `docker-cache-from` | Newline-separated cache-from sources. | `type=gha` |
| `docker-cache-to` | Newline-separated cache-to destinations. | `type=gha,mode=max` |

## Outputs

| Name | Description |
| --- | --- |
| `python-build-system` | Detected backend (`setuptools`, `hatchling`, `poetry`, `flit`, `pdm`, `unknown`, `none`). |
| `python-dist-path` | Absolute path to the produced `dist/` directory. |
| `docker-image-id` | Image ID returned by Buildx. |
| `docker-digest` | Pushed image digest (only when `docker-push: "true"`). |

## Usage

Just build sdist + wheel:

```yaml
- uses: actions/checkout@v4
- uses: saumitrapatil/bt-python-custom-action/actions/python-build-action@v1
```

Build sdist + wheel **and** push a Docker image to GHCR:

```yaml
- uses: actions/checkout@v4
- uses: saumitrapatil/bt-python-custom-action/actions/python-build-action@v1
  with:
    build-docker: "true"
    docker-push: "true"
    docker-registry: ghcr.io
    docker-username: ${{ github.actor }}
    docker-password: ${{ secrets.GITHUB_TOKEN }}
    docker-tags: |
      ghcr.io/${{ github.repository }}:${{ github.sha }}
      ghcr.io/${{ github.repository }}:latest
```

Build a multi-platform image (no push, multi-platform images can't be
`load`ed into the local daemon — useful for build smoke tests):

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-build-action@v1
  with:
    build-python: "false"
    build-docker: "true"
    docker-platforms: "linux/amd64,linux/arm64"
    docker-tags: |
      myorg/myapp:${{ github.sha }}
```

Build and load a single-platform image so a follow-up step can scan it with
[`trivy-image-action`](../trivy-image-action/):

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/python-build-action@v1
  id: build
  with:
    build-docker: "true"
    docker-load: "true"
    docker-tags: |
      local/myapp:${{ github.sha }}

- uses: saumitrapatil/bt-python-custom-action/actions/trivy-image-action@v1
  with:
    image-ref: local/myapp:${{ github.sha }}
```

## Example workflow

```yaml
name: release

on:
  push:
    tags: ["v*"]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: saumitrapatil/bt-python-custom-action/actions/python-build-action@v1
        with:
          build-docker: "true"
          docker-push: "true"
          docker-registry: ghcr.io
          docker-username: ${{ github.actor }}
          docker-password: ${{ secrets.GITHUB_TOKEN }}
          docker-tags: |
            ghcr.io/${{ github.repository }}:${{ github.ref_name }}
            ghcr.io/${{ github.repository }}:latest
```

## Required permissions

- Pushing to GHCR requires `packages: write`.
- Reading the repository requires `contents: read` (default for the standard
  `GITHUB_TOKEN`).

## Behavior notes

- The Python build runs `python -m build --sdist --wheel`. Editable installs
  are not produced — this action is for **publish-grade** dists.
- The action removes any pre-existing `dist/` before building so uploaded
  artifacts always reflect the current commit.
- Buildx cache uses `type=gha,mode=max` by default. For very large images,
  consider `type=registry,...` to share cache across branches.
- If `docker-push: "false"` and `docker-load: "false"`, the image is built
  inside the buildkit daemon and discarded — useful as a build smoke test.

## Security considerations

- `docker-password` is passed only to `docker/login-action` and never echoed.
- The login step runs **only** when `docker-registry`, `docker-username`,
  **and** `docker-password` are all non-empty. This prevents accidental
  unauthenticated push attempts that would otherwise fail with a confusing
  `unauthorized` error.
- All third-party actions (`actions/setup-python`, `docker/setup-buildx-action`,
  `docker/login-action`, `docker/build-push-action`, `actions/upload-artifact`)
  are pinned to a major version.
- The build script uses `set -euo pipefail`.

## Versioning strategy

This action is versioned alongside the rest of the monorepo. See the
top-level [README](../../README.md#versioning-strategy).

```yaml
# Pinned (recommended for production):
- uses: saumitrapatil/bt-python-custom-action/actions/python-build-action@v1.0.0

# Floating major:
- uses: saumitrapatil/bt-python-custom-action/actions/python-build-action@v1
```
