#!/usr/bin/env bash
# Logged git execution helpers.

set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Per-hour log path (UTC hour floored, e.g. 16:37 UTC -> ..._1600_UTC.log).
_evc_log_hour_stamp() {
  date -u +%Y%m%d_%H00_UTC
}

_evc_log_file() {
  local stamp
  stamp=$(_evc_log_hour_stamp)
  # Avoid creating .evc in an empty folder before clone (would make cwd non-empty).
  if [[ -d "${EVC_WORK_DIR}/.git" || -d "${EVC_WORK_DIR}/.evc" ]]; then
    ensure_evc_project_dirs
    echo "$(evc_logs_dir)/git_${stamp}.log"
  else
    local dir="${TMPDIR:-/tmp}/evc-pre-repo-logs"
    mkdir -p "${dir}"
    echo "${dir}/git_${stamp}.log"
  fi
}

# Git command lines and their output are indented under the evc invocation.
_EVC_LOG_INDENT="    "

# Write the evc command once per process, above the git commands it runs.
_evc_log_begin() {
  local logfile=$1
  if [[ "${EVC_LOG_HEADER_WRITTEN:-}" == "${logfile}" ]]; then
    return 0
  fi
  printf '%s\n' "${EVC_INVOCATION:-evc}" >>"${logfile}"
  EVC_LOG_HEADER_WRITTEN="${logfile}"
}

_evc_log_indent_stream() {
  sed "s/^/${_EVC_LOG_INDENT}/"
}

# Stage the worktree except .evc/. Those files are EVC bookkeeping.
# Adding an ignored .evc/ path makes git add exit 1, so .evc/ is left out of
# the pathspec entirely.
stage_all_except_internal() {
  run_git add -A -- . ':(exclude).evc' || return $?
}

# Runs git in EVC_WORK_DIR; command + full output go only to logs (not the terminal).
run_git() {
  local logfile ec
  logfile=$(_evc_log_file)
  _evc_log_begin "${logfile}"
  printf '%s+ git %s\n' "${_EVC_LOG_INDENT}" "$*" >>"${logfile}"
  set +e
  git -C "${EVC_WORK_DIR}" "$@" 2>&1 | _evc_log_indent_stream >>"${logfile}"
  ec=${PIPESTATUS[0]}
  set -e
  return "${ec}"
}

# Captures stdout of a git command (stderr still logged).
run_git_capture() {
  local logfile err ec=0
  logfile=$(_evc_log_file)
  _evc_log_begin "${logfile}"
  printf '%s+ git %s\n' "${_EVC_LOG_INDENT}" "$*" >>"${logfile}"
  err=$(mktemp)
  git -C "${EVC_WORK_DIR}" "$@" 2>"${err}" || ec=$?
  _evc_log_indent_stream <"${err}" >>"${logfile}"
  rm -f "${err}"
  return "${ec}"
}

require_git_repo() {
  git -C "${EVC_WORK_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "Not inside a Git repository: ${EVC_WORK_DIR}"
}

current_branch() {
  git -C "${EVC_WORK_DIR}" branch --show-current
}

branch_exists() {
  git -C "${EVC_WORK_DIR}" show-ref --verify --quiet "refs/heads/$1"
}

remote_exists() {
  git -C "${EVC_WORK_DIR}" remote get-url "$1" >/dev/null 2>&1
}

upstream_ref() {
  git -C "${EVC_WORK_DIR}" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true
}

has_origin() {
  remote_exists origin
}

is_rebase_in_progress() {
  local git_dir
  git_dir=$(git -C "${EVC_WORK_DIR}" rev-parse --git-dir)
  [[ -d "${git_dir}/rebase-merge" || -d "${git_dir}/rebase-apply" ]]
}

is_merge_in_progress() {
  local git_dir
  git_dir=$(git -C "${EVC_WORK_DIR}" rev-parse --git-dir)
  [[ -f "${git_dir}/MERGE_HEAD" ]]
}
