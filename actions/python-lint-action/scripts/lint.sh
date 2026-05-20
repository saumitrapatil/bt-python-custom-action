#!/usr/bin/env bash
# Lint Python code with Ruff, optionally Black and MyPy.
#
# Environment variables (set by action.yml):
#   INPUT_RUN_BLACK      - "true" to also run `black --check`.
#   INPUT_RUN_MYPY       - "true" to also run `mypy`.
#   INPUT_RUFF_VERSION   - Pinned Ruff version (empty = latest).
#   INPUT_BLACK_VERSION  - Pinned Black version (empty = latest).
#   INPUT_MYPY_VERSION   - Pinned MyPy version (empty = latest).

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

# ----- output helpers --------------------------------------------------------
write_output() {
  local name="$1"
  local value="$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf "%s=%s\n" "${name}" "${value}" >> "${GITHUB_OUTPUT}"
  fi
}

# ----- dependency detection --------------------------------------------------
log_info "Working directory: $(pwd)"

if [[ -f "requirements.txt" ]]; then
  log_info "Detected requirements.txt — installing project dependencies."
  python -m pip install --upgrade pip
  python -m pip install -r requirements.txt
elif [[ -f "pyproject.toml" ]]; then
  log_info "Detected pyproject.toml — installing project (no extras)."
  python -m pip install --upgrade pip
  # Best-effort: install the project so type-checking sees its modules.
  # We don't fail the lint job if the project isn't installable as a package.
  python -m pip install . || log_warn "Project not installable via pip; continuing."
else
  log_warn "Neither requirements.txt nor pyproject.toml found — skipping dependency install."
  python -m pip install --upgrade pip
fi

# ----- linter installation ---------------------------------------------------
install_tool() {
  local pkg="$1"
  local version="$2"
  if [[ -n "${version}" ]]; then
    log_info "Installing ${pkg}==${version}"
    python -m pip install "${pkg}==${version}"
  else
    log_info "Installing ${pkg} (latest)"
    python -m pip install "${pkg}"
  fi
}

install_tool ruff "${INPUT_RUFF_VERSION:-}"

if [[ "${INPUT_RUN_BLACK:-false}" == "true" ]]; then
  install_tool black "${INPUT_BLACK_VERSION:-}"
fi

if [[ "${INPUT_RUN_MYPY:-false}" == "true" ]]; then
  install_tool mypy "${INPUT_MYPY_VERSION:-}"
fi

# ----- run linters -----------------------------------------------------------
# `$?` inside `if ! cmd; then` captures the *negated* exit. We use the
# `cmd || exit=$?` idiom so the real exit code is preserved for the output.
failures=()

log_info "Running ruff check"
ruff_exit=0
ruff check . || ruff_exit=$?
if (( ruff_exit != 0 )); then
  failures+=("ruff")
fi
write_output "ruff-exit-code" "${ruff_exit}"

if [[ "${INPUT_RUN_BLACK:-false}" == "true" ]]; then
  log_info "Running black --check"
  black_exit=0
  black --check . || black_exit=$?
  if (( black_exit != 0 )); then
    failures+=("black")
  fi
  write_output "black-exit-code" "${black_exit}"
else
  write_output "black-exit-code" ""
fi

if [[ "${INPUT_RUN_MYPY:-false}" == "true" ]]; then
  log_info "Running mypy"
  mypy_exit=0
  # Exclude build/ and dist/: a prior `pip install .` builds the project
  # in-tree, leaving copies of source modules that make mypy report
  # "Duplicate module" errors.
  mypy --exclude '(^|/)(build|dist)($|/)' . || mypy_exit=$?
  if (( mypy_exit != 0 )); then
    failures+=("mypy")
  fi
  write_output "mypy-exit-code" "${mypy_exit}"
else
  write_output "mypy-exit-code" ""
fi

# ----- exit ------------------------------------------------------------------
if (( ${#failures[@]} > 0 )); then
  log_error "Lint failures: ${failures[*]}"
  exit 1
fi

log_info "All configured linters passed."
