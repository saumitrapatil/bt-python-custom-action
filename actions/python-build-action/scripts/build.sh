#!/usr/bin/env bash
# Detect the Python build backend and build sdist + wheel via PEP 517.
#
# Environment variables (set by action.yml):
#   INPUT_BUILD_TOOL_VERSION  - Pinned PyPA `build` version (empty = latest).

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

# ----- detect build backend --------------------------------------------------
detect_build_system() {
  if [[ -f "pyproject.toml" ]]; then
    # Grep is enough — we just need a hint about which backend the project uses.
    # PEP 517 build still works the same regardless of the backend.
    if   grep -qE '^\s*requires\s*=.*"poetry-core'                pyproject.toml; then printf "poetry"
    elif grep -qE '^\s*requires\s*=.*"hatchling'                  pyproject.toml; then printf "hatchling"
    elif grep -qE '^\s*requires\s*=.*"flit_core'                  pyproject.toml; then printf "flit"
    elif grep -qE '^\s*requires\s*=.*"pdm-backend'                pyproject.toml; then printf "pdm"
    elif grep -qE '^\s*requires\s*=.*"setuptools'                 pyproject.toml; then printf "setuptools"
    elif grep -qE '^\s*build-backend\s*=\s*"setuptools'           pyproject.toml; then printf "setuptools"
    else                                                                                printf "unknown"
    fi
  elif [[ -f "setup.py" || -f "setup.cfg" ]]; then
    printf "setuptools"
  else
    printf "none"
  fi
}

log_info "Working directory: $(pwd)"

build_system="$(detect_build_system)"
write_output "build-system" "${build_system}"

if [[ "${build_system}" == "none" ]]; then
  log_error "No pyproject.toml, setup.py, or setup.cfg found. Nothing to build."
  exit 1
fi
log_info "Detected Python build backend: ${build_system}"

# ----- install builder -------------------------------------------------------
python -m pip install --upgrade pip

if [[ -n "${INPUT_BUILD_TOOL_VERSION:-}" ]]; then
  log_info "Installing build==${INPUT_BUILD_TOOL_VERSION}"
  python -m pip install "build==${INPUT_BUILD_TOOL_VERSION}"
else
  log_info "Installing build (latest)"
  python -m pip install build
fi

# ----- build -----------------------------------------------------------------
# Clean any stale dist/ from previous runs so the uploaded artifact is exact.
if [[ -d "dist" ]]; then
  log_info "Cleaning existing dist/"
  rm -rf dist
fi

log_info "Building sdist + wheel via PEP 517"
python -m build --sdist --wheel --outdir dist .

# ----- report ----------------------------------------------------------------
dist_path="$(pwd)/dist"
write_output "dist-path" "${dist_path}"

log_info "Built artifacts:"
ls -lh dist
