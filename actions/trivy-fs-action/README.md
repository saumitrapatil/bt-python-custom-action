# trivy-fs-action

Scan the repository filesystem with [Trivy](https://trivy.dev/), generate a
SARIF report, and upload the results to the GitHub Security tab.

This action is a thin, opinionated wrapper around
[`aquasecurity/trivy-action`](https://github.com/aquasecurity/trivy-action)
that enforces organization-wide defaults so that every Python repository in
the org reports vulnerabilities, leaked secrets, and Dockerfile/IaC
misconfigurations the same way.

## Features

- Scans the repository filesystem for vulnerabilities, leaked secrets, and
  misconfigurations.
- Produces a SARIF report on every run.
- Uploads SARIF to the GitHub **Security → Code scanning** tab so findings
  show up inline on pull requests.
- Also uploads SARIF as a workflow artifact for traceability.
- Honors `.trivyignore` files out of the box.
- Defaults to `CRITICAL,HIGH` severities with `ignore-unfixed=true` to keep
  the signal-to-noise ratio high.
- Supports a `category` input so multiple Trivy runs (fs + image) can coexist
  in the Security tab without overwriting one another.

## Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `scan-ref` | Path to scan (relative to workspace root). | No | `.` |
| `severity` | Comma-separated severities. | No | `CRITICAL,HIGH` |
| `ignore-unfixed` | Only report vulns with a fix available. | No | `true` |
| `exit-code` | Exit code when vulns are found. `0` to never fail. | No | `1` |
| `scanners` | Comma-separated scanners. `misconfig` scans Dockerfiles/IaC. | No | `vuln,secret,misconfig` |
| `trivyignores` | Newline-separated list of `.trivyignore` files. Empty = none. | No | `""` |
| `skip-dirs` | Comma-separated directories to skip. | No | `""` |
| `sarif-file` | Path of the generated SARIF report. | No | `trivy-fs-results.sarif` |
| `upload-sarif` | Upload SARIF to GitHub Security. | No | `true` |
| `category` | SARIF category label. | No | `trivy-fs` |
| `trivy-version` | Trivy CLI version (empty = action default). | No | `""` |

## Outputs

| Name | Description |
| --- | --- |
| `sarif-path` | Path to the generated SARIF report. |

## Dockerfile & IaC misconfiguration scanning

The default `scanners` value includes `misconfig`, so this single action also
scans **Dockerfiles** and other Infrastructure-as-Code for insecure defaults —
there is no separate config-scan action to wire up. Trivy auto-detects and
checks Dockerfiles, docker-compose, Kubernetes manifests, Terraform,
CloudFormation, and Helm anywhere under `scan-ref`.

**One caveat — the shared severity filter.** Many Dockerfile misconfigurations
(no `USER`, `:latest` base image) are rated `MEDIUM` by Trivy. The default
`severity` here is `CRITICAL,HIGH` to keep vulnerability noise down, so those
`MEDIUM` misconfigs are filtered out of the report. If misconfiguration
coverage matters for your repo, broaden the severity:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-fs-action@v1
  with:
    severity: "CRITICAL,HIGH,MEDIUM"
```

To gate **only** on misconfigurations as a dedicated job, run the action a
second time with a narrowed scanner set and its own category:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-fs-action@v1
  with:
    scanners: "misconfig"
    severity: "CRITICAL,HIGH,MEDIUM"
    category: "trivy-misconfig"
```

## Usage

Minimal — enforce org defaults, upload SARIF to Security tab:

```yaml
- uses: actions/checkout@v4
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-fs-action@v1
```

Audit-only (do not fail the build, just publish results):

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-fs-action@v1
  with:
    exit-code: "0"
```

Stricter severity for a security-critical service:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-fs-action@v1
  with:
    severity: "CRITICAL,HIGH,MEDIUM"
    ignore-unfixed: "false"
```

Monorepo subdirectory:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-fs-action@v1
  with:
    scan-ref: services/api
    category: "trivy-fs-api"
```

## Example workflow

```yaml
name: security

on:
  pull_request:
  push:
    branches: [main]
  schedule:
    - cron: "0 6 * * 1"   # weekly Monday 06:00 UTC

jobs:
  trivy-fs:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write   # required to upload SARIF
    steps:
      - uses: actions/checkout@v4
      - uses: saumitrapatil/bt-python-custom-action/actions/trivy-fs-action@v1
        with:
          severity: "CRITICAL,HIGH"
```

## Required permissions

When `upload-sarif: "true"` (the default), the job must declare:

```yaml
permissions:
  contents: read
  security-events: write
```

Without `security-events: write`, the SARIF upload step will fail with a
`Resource not accessible by integration` error.

## Security considerations

- Third-party action `aquasecurity/trivy-action` is pinned to an immutable
  version. Bump intentionally and review release notes.
- The SARIF upload uses `github/codeql-action/upload-sarif@v3`, the official
  GitHub CodeQL action.
- No secrets are required or echoed by this action.
- Findings are uploaded to the **Security → Code scanning** tab. Treat that
  surface as the authoritative source of truth and avoid copying findings
  into PR comments where they may be missed.

## Versioning strategy

This action is versioned alongside the rest of the monorepo. See the
top-level [README](../../README.md#versioning-strategy).

```yaml
# Pinned (recommended for production):
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-fs-action@v1.0.0

# Floating major:
- uses: saumitrapatil/bt-python-custom-action/actions/trivy-fs-action@v1
```
