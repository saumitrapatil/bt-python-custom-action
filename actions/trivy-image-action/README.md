# trivy-image-action

Scan a container image with [Trivy](https://trivy.dev/), generate a SARIF
report, and upload the results to the GitHub Security tab.

This is the image-scanning sibling of
[`trivy-fs-action`](../trivy-fs-action/). Use this one to scan the image
your CI just built (or any image already published to a registry).

## Features

- Scans an OCI image for vulnerabilities and leaked secrets.
- Produces a SARIF report on every run.
- Uploads SARIF to the GitHub **Security → Code scanning** tab.
- Also uploads SARIF as a workflow artifact.
- Supports private registry authentication via `registry-username` /
  `registry-password`.
- Defaults to `CRITICAL,HIGH` severities with `ignore-unfixed=true`.
- Supports a `category` input so multiple Trivy runs (fs + image) can coexist
  in the Security tab.

## Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `image-ref` | Image to scan, e.g. `ghcr.io/org/app:sha-abc123`. | **Yes** | — |
| `severity` | Comma-separated severities. | No | `CRITICAL,HIGH` |
| `ignore-unfixed` | Only report vulns with a fix available. | No | `true` |
| `exit-code` | Exit code when vulns are found. `0` to never fail. | No | `1` |
| `scanners` | Comma-separated scanners. | No | `vuln,secret` |
| `vuln-type` | Comma-separated vuln types (`os,library`). | No | `os,library` |
| `sarif-file` | Path of the generated SARIF report. | No | `trivy-image-results.sarif` |
| `upload-sarif` | Upload SARIF to GitHub Security. | No | `true` |
| `category` | SARIF category label. | No | `trivy-image` |
| `registry-username` | Username for private registry auth. | No | `""` |
| `registry-password` | Password/token for private registry auth. | No | `""` |
| `trivy-version` | Trivy CLI version (empty = action default). | No | `""` |

## Outputs

| Name | Description |
| --- | --- |
| `sarif-path` | Path to the generated SARIF report. |

## Usage

Scan an image that was just built and loaded into the local Docker daemon:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-image-action@v1
  with:
    image-ref: "myorg/myapp:${{ github.sha }}"
```

Scan an image in a private registry:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-image-action@v1
  with:
    image-ref: "ghcr.io/myorg/myapp:${{ github.sha }}"
    registry-username: ${{ github.actor }}
    registry-password: ${{ secrets.GITHUB_TOKEN }}
```

Audit-only mode (publish to Security tab but never fail the build):

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-image-action@v1
  with:
    image-ref: "myorg/myapp:nightly"
    exit-code: "0"
```

## Example workflow

```yaml
name: ci

on:
  pull_request:
  push:
    branches: [main]

jobs:
  build-and-scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
      packages: write
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          context: .
          load: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}

      - uses: saumitrapatil/bt-python-custom-action/actions/trivy-image-action@v1
        with:
          image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
          severity: "CRITICAL,HIGH"
```

## Required permissions

When `upload-sarif: "true"` (the default), the job must declare:

```yaml
permissions:
  contents: read
  security-events: write
```

## Security considerations

- `registry-password` is forwarded to Trivy via the `TRIVY_PASSWORD`
  environment variable, never echoed.
- For private registries, prefer a short-lived `GITHUB_TOKEN` or a registry
  service account over a long-lived personal token.
- The upstream `aquasecurity/trivy-action` is pinned to an immutable version.
- Findings appear in the **Security → Code scanning** tab — treat it as
  authoritative.

## Versioning strategy

This action is versioned alongside the rest of the monorepo. See the
top-level [README](../../README.md#versioning-strategy).

```yaml
# Pinned (recommended for production):
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-image-action@v1.0.0

# Floating major:
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-image-action@v1
```
