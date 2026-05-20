#!/usr/bin/env bash
# Run pytest with coverage and emit coverage.xml + junit.xml.
#
# Environment variables (set by action.yml):
#   INPUT_PYTEST_ARGS       - Extra arguments to forward to pytest.
#   INPUT_FAIL_ON_NO_TESTS  - "true" to fail when pytest collects no tests.

set -euo pipefail

# ----- logging helpers -------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_INFO=$'\033[1;34m'
  C_WARN=$'\033[1;33m'
  C_ERR=$'\033[1;31m'
else
  C_RESET=""
  C_INFO=""
  C_WARN=""
  C_ERR=""
fi

log_info()  { printf "%s[INFO]%s  %s\n"  "${C_INFO}" "${C_RESET}" "$*"; }
log_warn()  { printf "%s[WARN]%s  %s\n"  "${C_WARN}" "${C_RESET}" "$*" >&2; }
log_error() { printf "%s[ERROR]%s %s\n" "${C_ERR}"  "${C_RESET}" "$*" >&2; }

write_output() {
  local name="$1"
  local value="$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf "%s=%s\n" "${name}" "${value}" >> "${GITHUB_OUTPUT}"
  fi
}

# ----- dependency install ----------------------------------------------------
log_info "Working directory: $(pwd)"
python -m pip install --upgrade pip

if [[ -f "requirements.txt" ]]; then
  log_info "Installing project dependencies from requirements.txt"
  python -m pip install -r requirements.txt
elif [[ -f "pyproject.toml" ]]; then
  log_info "Installing project from pyproject.toml"
  # Install with test extras if defined; fall back to a plain install otherwise.
  python -m pip install ".[test]" 2>/dev/null \
    || python -m pip install ".[dev]"  2>/dev/null \
    || python -m pip install .          2>/dev/null \
    || log_warn "Project not installable via pip; continuing."
else
  log_warn "No requirements.txt or pyproject.toml found — skipping project install."
fi

log_info "Installing pytest and pytest-cov"
python -m pip install pytest pytest-cov

# ----- run pytest ------------------------------------------------------------
log_info "Running pytest with coverage"

# Word-split INPUT_PYTEST_ARGS intentionally — it's a CLI string.
set +e
# shellcheck disable=SC2086
pytest \
  --cov=. \
  --cov-report=xml \
  --cov-report=term \
  --junitxml=junit.xml \
  ${INPUT_PYTEST_ARGS:-}
pytest_exit=$?
set -e

# pytest exit codes:
#   0 - all tests passed
#   1 - tests collected, some failed
#   2 - test execution interrupted
#   3 - internal error
#   4 - pytest command-line usage error
#   5 - no tests collected
if [[ "${pytest_exit}" -eq 5 ]]; then
  if [[ "${INPUT_FAIL_ON_NO_TESTS:-true}" == "true" ]]; then
    log_error "pytest collected no tests (exit code 5)."
    exit 5
  else
    log_warn "pytest collected no tests — continuing because fail-on-no-tests=false."
    pytest_exit=0
  fi
fi

# ----- record artifact paths -------------------------------------------------
coverage_path=""
junit_path=""

if [[ -f "coverage.xml" ]]; then
  coverage_path="$(pwd)/coverage.xml"
  log_info "Coverage report: ${coverage_path}"
else
  log_warn "coverage.xml was not produced."
fi

if [[ -f "junit.xml" ]]; then
  junit_path="$(pwd)/junit.xml"
  log_info "JUnit report: ${junit_path}"
else
  log_warn "junit.xml was not produced."
fi

write_output "coverage-report-path" "${coverage_path}"
write_output "junit-report-path" "${junit_path}"

if [[ "${pytest_exit}" -ne 0 ]]; then
  log_error "pytest exited with code ${pytest_exit}"
  exit "${pytest_exit}"
fi

log_info "Coverage run completed successfully."
