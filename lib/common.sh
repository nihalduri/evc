#!/usr/bin/env bash
# Shared helpers for EVC. Expects EVC_INSTALL_ROOT and EVC_WORK_DIR (cwd) set.

set -euo pipefail

die() {
  echo "Error: $*" >&2
  exit 1
}

# For internal Git failures; details are in the project logs.
die_oops() {
  die "Oops, something went wrong. Check the logs (.evc/logs)."
}

info() {
  echo "$*"
}

require_args() {
  local desc=$1
  shift
  [[ $# -ge 1 && -n "${1:-}" ]] || die "${desc}"
}

# Project-local EVC metadata. Nothing under .evc/ is committed.
evc_dot_dir() {
  [[ -n "${EVC_WORK_DIR:-}" ]] || die "Internal error: EVC_WORK_DIR unset."
  echo "${EVC_WORK_DIR}/.evc"
}

evc_logs_dir() {
  echo "$(evc_dot_dir)/logs"
}

# One line: the configured main branch name. Absent means "main".
evc_main_branch_file() {
  echo "$(evc_dot_dir)/main-branch-name"
}

# Default-branch name for this project (main unless configure-main-branch-name was used).
evc_main_branch() {
  local f name=""
  f=$(evc_main_branch_file)
  if [[ -f "${f}" ]]; then
    IFS= read -r name <"${f}" || true
    name=${name%$'\r'}
  fi
  if [[ -n "${name}" ]]; then
    printf '%s\n' "${name}"
  else
    printf '%s\n' "main"
  fi
}

ensure_evc_project_dirs() {
  mkdir -p "$(evc_logs_dir)"
}

# Returns 0 for yes, 1 for no. Accepts only Y or N.
ask_yn() {
  local prompt=$1
  local answer
  while true; do
    echo "${prompt}"
    read -r answer || die "Input closed."
    case "${answer}" in
      Y) return 0 ;;
      N) return 1 ;;
      *) echo "Option not recognized. Please type 'Y' or 'N'." ;;
    esac
  done
}
