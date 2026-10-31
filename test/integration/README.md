# EVC integration tests

These tests exercise EVC commands that use a Git remote (`pull`, `merge-into`, `push`, and `clone`).

## Prerequisites

### Default (`pull_push.bats`) — no remote prerequisites

These tests spin up a **local bare repository** as `origin` in the bats temp directory. You do **not** need GitHub, SSH keys, or network access.

Requirements:

- `git` available on `PATH`
- bash (Git Bash on Windows is fine)
- bats submodules initialized (see below)

### Optional networked remote (`remote_network.bats` only)

Skipped automatically unless you set:

| Variable | Purpose |
|---|---|
| `EVC_TEST_REMOTE_URL` | HTTPS or SSH URL of an **empty** (or disposable) remote repository you can force-push to |

When set, `remote_network.bats` will `clone` / `pull` / `push` against that URL. Use a throwaway repo; tests may rewrite its history.

## Running

From the EVC project root:

```bash
# one-time: initialize test submodules
git submodule update --init --recursive test

# unit tests (no remote)
./test/bats/bin/bats test/unit

# integration tests (local bare remotes)
./test/bats/bin/bats test/integration

# optional networked tests
EVC_TEST_REMOTE_URL='git@github.com:you/evc-test.git' ./test/bats/bin/bats test/integration/remote_network.bats
```

Or run both suites:

```bash
./test/bats/bin/bats test/unit test/integration
```
