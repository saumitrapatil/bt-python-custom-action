# trufflehog-action

Scan the repository for leaked secrets with
[TruffleHog OSS](https://github.com/trufflesecurity/trufflehog).

This action wraps [`trufflesecurity/trufflehog`](https://github.com/trufflesecurity/trufflehog)
with org-wide defaults and auto-detects the right scan scope based on the
event type (`diff` on pull requests, `full` history on pushes and schedules).

## Features

- **Auto-scoped scans.** Pull requests get a fast diff scan between the PR
  base and head; push and schedule events scan a wider scope. You can
  override with `scan-mode: full` or `scan-mode: diff`.
- **Only-verified by default.** Reduces noise — TruffleHog tests each candidate
  secret against the real service before reporting it.
- **Fail-on-detection toggle.** Default is to fail the job when any secret is
  found; flip to false to run in audit mode.
- **Force-push safe.** If the push event has no usable base SHA, the action
  falls back to a full scan instead of crashing.

## Inputs

| Name | Description | Required | Default |
| --- | --- | --- | --- |
| `path` | Path to scan. | No | `./` |
| `scan-mode` | `auto`, `diff`, or `full`. | No | `auto` |
| `only-verified` | Only report verified secrets. | No | `true` |
| `fail-on-detection` | Fail the job when secrets are found. | No | `true` |
| `extra-args` | Additional flags forwarded to trufflehog. | No | `""` |

## Outputs

| Name | Description |
| --- | --- |
| `results-found` | `'true'` if TruffleHog reported any findings. |

## Usage

Minimal — auto scope, fail on any verified leak:

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0   # TruffleHog needs history for diff scans
- uses: saumitrapatil/bt-python-custom-action/actions/trufflehog-action@v1
```

Audit mode (report but never fail):

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/trufflehog-action@v1
  with:
    fail-on-detection: "false"
```

Force a full-history scan on every event:

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/trufflehog-action@v1
  with:
    scan-mode: "full"
```

Include unverified findings (noisier, useful for one-off audits):

```yaml
- uses: saumitrapatil/bt-python-custom-action/actions/trufflehog-action@v1
  with:
    only-verified: "false"
```

## Example workflow

```yaml
name: secrets

on:
  pull_request:
  push:
    branches: [main]
  schedule:
    - cron: "0 4 * * *"   # daily 04:00 UTC

jobs:
  trufflehog:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: saumitrapatil/bt-python-custom-action/actions/trufflehog-action@v1
```

## Required permissions

```yaml
permissions:
  contents: read
```

No `security-events: write` is required — TruffleHog findings are surfaced
via the job log (and the action's exit code), not the GitHub Security tab.

## Important: `fetch-depth: 0`

Diff scans inspect the commit range `base..head`. The default `checkout@v4`
fetches only the most recent commit and will produce empty diffs. **Always**
combine this action with `actions/checkout@v4` configured for
`fetch-depth: 0` (or at least a depth that covers the PR commit range).

## Behavior matrix

| Event | `scan-mode=auto` resolves to | Base | Head |
| --- | --- | --- | --- |
| `pull_request` | `diff` | PR base SHA | PR head SHA |
| `pull_request_target` | `diff` | PR base SHA | PR head SHA |
| `push` (normal) | `diff` | `github.event.before` | `github.event.after` |
| `push` (first push / force-push w/o base) | `full` | — | — |
| `schedule`, `workflow_dispatch`, others | `full` | — | — |

## Security considerations

- The upstream `trufflesecurity/trufflehog` action is pinned to a commit SHA
  (`v3.95.3`) directly in `action.yml`. GitHub Actions does not allow `${{ }}`
  expressions in a `uses:` reference, so this version cannot be exposed as an
  input — bump it by editing `action.yml` (Dependabot keeps it current
  automatically).
- `--only-verified` is the default to avoid spamming PR authors with
  false-positive findings.
- The action runs with `contents: read` only.
- Findings appear in the job log. If you need a structured artifact, add a
  follow-up step that re-runs TruffleHog with `--json` against the same
  range — keep that step in the same workflow so a leaked secret cannot
  be exfiltrated by an attacker modifying CI in a fork PR.

## Versioning strategy

This action is versioned alongside the rest of the monorepo. See the
top-level [README](../../README.md#versioning-strategy).

```yaml
# Pinned (recommended for production):
- uses: saumitrapatil/bt-python-custom-action/actions/trufflehog-action@v1.0.0

# Floating major:
- uses: saumitrapatil/bt-python-custom-action/actions/trufflehog-action@v1
```
