#!/usr/bin/env bash
# evc merge-into NAME --order b1,b2,...
# Merge each branch into NAME. A tip already contained in NAME is skipped.

set -euo pipefail

# shellcheck source=../lib/remote.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/remote.sh"

_merge_into_usage() {
  die "Usage: evc merge-into <NAME> --order <BRANCH1>,<BRANCH2>,..."
}

# Label conflict markers with the branch being updated and the branch merged in.
_pretty_merge_into_conflict_markers() {
  local existing=$1 incoming=$2 file tmp
  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    tmp=$(mktemp)
    awk -v existing="${existing}" -v incoming="${incoming}" '
      {
        line = $0
        sub(/\r$/, "", line)
        if (line == "<<<<<<< HEAD") { print "<<<<<<< " existing; next }
        if (line ~ /^>>>>>>> /) { print ">>>>>>> " incoming; next }
        print
      }
    ' "${EVC_WORK_DIR}/${file}" >"${tmp}"
    mv "${tmp}" "${EVC_WORK_DIR}/${file}"
  done < <(git -C "${EVC_WORK_DIR}" diff --name-only --diff-filter=U)
}

_commit_merge_into_conflict() {
  local existing=$1 incoming=$2
  is_merge_in_progress || return 1
  _pretty_merge_into_conflict_markers "${existing}" "${incoming}"
  stage_all_except_internal || die_oops
  run_git commit --no-edit || die_oops
  return 0
}

_incoming_merge_name() {
  local name
  name=$(git -C "${EVC_WORK_DIR}" name-rev --name-only MERGE_HEAD 2>/dev/null || true)
  name=${name%%~*}
  name=${name%%^*}
  name=${name#remotes/origin/}
  if [[ -z "${name}" || "${name}" == "undefined" ]]; then
    name="incoming"
  fi
  printf '%s\n' "${name}"
}

# True when ORDER_CSV has a branch after CONFLICT.
_order_continues_after() {
  local order_csv=$1 conflict=$2
  local feature seen=0
  local IFS=,
  for feature in ${order_csv}; do
    [[ -n "${feature}" ]] || continue
    if [[ "${seen}" -eq 1 ]]; then
      return 0
    fi
    [[ "${feature}" == "${conflict}" ]] && seen=1
  done
  return 1
}

# Merge INCOMING into the current branch. TARGET is that branch's name.
# Sets EVC_MERGE_INTO_CONFLICT when conflict markers were committed.
_merge_into_current() {
  local target=$1 incoming=$2
  EVC_MERGE_INTO_CONFLICT=""
  branch_exists "${incoming}" || die "Branch '${incoming}' does not exist."
  if git -C "${EVC_WORK_DIR}" merge-base --is-ancestor "${incoming}" HEAD 2>/dev/null; then
    info "Skipping '${incoming}' (already contained in '${target}')."
    return 0
  fi
  if ! run_git merge -m "EVC merge-into: merge ${incoming}" "${incoming}"; then
    _commit_merge_into_conflict "${target}" "${incoming}" || die_oops
    EVC_MERGE_INTO_CONFLICT="${incoming}"
    return 0
  fi
  info "Merged '${incoming}'."
}

cmd_merge_into() {
  local name="" order=""
  [[ $# -ge 1 && "$1" != -* ]] || _merge_into_usage
  name=$1
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --order)
        [[ $# -ge 2 ]] || _merge_into_usage
        order=$2
        shift 2
        ;;
      *)
        _merge_into_usage
        ;;
    esac
  done
  [[ -n "${name}" && -n "${order}" ]] || _merge_into_usage

  require_git_repo
  local main
  main=$(evc_main_branch)
  [[ "${name}" != "${main}" ]] || die "Cannot merge into '${main}'."
  branch_exists "${name}" || die "Feature '${name}' does not exist."

  EVC_MERGE_INTO_CONFLICT=""
  maybe_preserve_work

  if is_merge_in_progress; then
    _commit_merge_into_conflict "$(current_branch)" "$(_incoming_merge_name)" || die_oops
  fi

  run_git checkout "${name}" || die_oops

  local feature old_ifs="${IFS}"
  IFS=,
  for feature in ${order}; do
    [[ -n "${feature}" && "${feature}" != "${name}" ]] || continue
    _merge_into_current "${name}" "${feature}"
    if [[ -n "${EVC_MERGE_INTO_CONFLICT}" ]]; then
      break
    fi
  done
  IFS="${old_ifs}"

  local conflict="${EVC_MERGE_INTO_CONFLICT}"
  restore_stashed_work_as_snapshot

  if [[ -n "${conflict}" ]]; then
    info "Merge conflicts were recorded on '${name}' while merging '${conflict}'. Conflict markers are in the files; edit them to the resolution you want."
    if _order_continues_after "${order}" "${conflict}"; then
      info "After resolving them, run: evc merge-into ${name} --order ${order}"
    fi
    return 0
  fi
  info "merge-into complete on branch '${name}'."
}
