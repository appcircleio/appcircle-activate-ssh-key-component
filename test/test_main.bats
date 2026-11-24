#!/usr/bin/env bats
#
# Unit tests for main.sh (Activate SSH Private Key step).
#
#   bats test/
#
# The step is run as a subprocess with a clean environment (`env -i`):
#   - HOME points to a per-test tmpdir, so `rm -rf ~/.ssh` and every file the
#     step writes stay inside BATS_TEST_TMPDIR.
#   - Stub `ssh-agent` and `ssh-add` are first on PATH. They only log their
#     arguments, so the real SSH toolchain is never started.

bats_require_minimum_version 1.5.0

MAIN_SH="${BATS_TEST_DIRNAME}/../main.sh"
STUB_SOCK="/tmp/ssh-stub/agent.4242"

# A realistic multi-line key (dummy content, not a real key).
TEST_KEY="-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACDummyDummyDummyDummyDummyDummyDummyDummyDummyAAAAAAAAAA==
-----END OPENSSH PRIVATE KEY-----"

setup() {
  WORK="${BATS_TEST_TMPDIR}/work"
  FAKE_HOME="${WORK}/home"
  FAKE_BIN="${WORK}/bin"
  CALLS="${WORK}/calls.log"
  ENV_FILE="${WORK}/ac_env"
  BASH_BIN="$(command -v bash)"
  mkdir -p "$FAKE_HOME" "$FAKE_BIN"
  : > "$CALLS"

  # ssh-agent prints the same eval-able output as the real one.
  cat > "${FAKE_BIN}/ssh-agent" <<'STUB'
#!/bin/bash
echo "ssh-agent $*" >> "$STUB_CALLS"
if [ -n "$STUB_SSH_AGENT_EXIT" ]; then
  echo "ssh-agent: stub failure" >&2
  exit "$STUB_SSH_AGENT_EXIT"
fi
echo "SSH_AUTH_SOCK=${STUB_SOCK}; export SSH_AUTH_SOCK;"
echo "SSH_AGENT_PID=4242; export SSH_AGENT_PID;"
echo "echo Agent pid 4242;"
STUB

  # ssh-add logs its arguments and the agent socket it sees.
  cat > "${FAKE_BIN}/ssh-add" <<'STUB'
#!/bin/bash
echo "ssh-add $* [SSH_AUTH_SOCK=${SSH_AUTH_SOCK}]" >> "$STUB_CALLS"
if [ -n "$STUB_SSH_ADD_EXIT" ]; then
  echo "Error loading key \"$1\": invalid format" >&2
  exit "$STUB_SSH_ADD_EXIT"
fi
echo "Identity added: $1"
STUB

  chmod +x "${FAKE_BIN}/ssh-agent" "${FAKE_BIN}/ssh-add"
}

# run_step [VAR=value ...]
# Runs main.sh with only the given variables (plus HOME/PATH and stub settings).
run_step() {
  run --separate-stderr env -i \
    HOME="$FAKE_HOME" \
    PATH="${FAKE_BIN}:/usr/bin:/bin" \
    STUB_CALLS="$CALLS" \
    STUB_SOCK="$STUB_SOCK" \
    "$@" \
    "$BASH_BIN" "$MAIN_SH"
}

# Exact octal mode check that works with both BSD and GNU find.
has_mode() {
  [ -n "$(find "$1" -prune -perm "$2")" ]
}

seed_existing_ssh_dir() {
  mkdir -p "${FAKE_HOME}/.ssh"
  echo "stale-known-host" > "${FAKE_HOME}/.ssh/known_hosts"
  echo "stale-key" > "${FAKE_HOME}/.ssh/appcircle_ssh"
  echo "Host stale" > "${FAKE_HOME}/.ssh/config"
}

# ---------------------------------------------------------------------------
# Loading contract
# ---------------------------------------------------------------------------

@test "sourcing main.sh returns 0 and does not run the step" {
  run --separate-stderr env -i HOME="$FAKE_HOME" PATH="${FAKE_BIN}:/usr/bin:/bin" \
    STUB_CALLS="$CALLS" STUB_SOCK="$STUB_SOCK" \
    AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE" \
    "$BASH_BIN" -c 'source "$1"; echo "source-status=$?"; echo "flags=$-"' _ "$MAIN_SH"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "source-status=0" ]
  [[ "${lines[1]}" != *e* ]]          # `set -e` did not leak into the caller
  [ ! -e "${FAKE_HOME}/.ssh" ]
  [ ! -e "$ENV_FILE" ]
  [ ! -s "$CALLS" ]
}

@test "sourcing main.sh keeps an existing ~/.ssh untouched" {
  seed_existing_ssh_dir

  run env -i HOME="$FAKE_HOME" PATH="${FAKE_BIN}:/usr/bin:/bin" \
    AC_REPOSITORY_SSH_KEY="$TEST_KEY" \
    "$BASH_BIN" -c 'source "$1"' _ "$MAIN_SH"

  [ "$status" -eq 0 ]
  [ "$(cat "${FAKE_HOME}/.ssh/known_hosts")" = "stale-known-host" ]
  [ "$(cat "${FAKE_HOME}/.ssh/appcircle_ssh")" = "stale-key" ]
}

# ---------------------------------------------------------------------------
# AC_REPOSITORY_SSH_KEY (optional input: missing/empty skips the step)
# ---------------------------------------------------------------------------

@test "AC_REPOSITORY_SSH_KEY missing: skips the step with exit 0" {
  run_step AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  [ "$output" = "AC_REPOSITORY_SSH_KEY is not provided. Skipping step." ]
  [ -z "$stderr" ]
  [ ! -e "${FAKE_HOME}/.ssh" ]
  [ ! -e "$ENV_FILE" ]
  [ ! -s "$CALLS" ]
}

@test "AC_REPOSITORY_SSH_KEY empty: skips the step with exit 0" {
  run_step AC_REPOSITORY_SSH_KEY="" AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  [ "$output" = "AC_REPOSITORY_SSH_KEY is not provided. Skipping step." ]
  [ ! -e "${FAKE_HOME}/.ssh" ]
  [ ! -e "$ENV_FILE" ]
  [ ! -s "$CALLS" ]
}

@test "AC_REPOSITORY_SSH_KEY missing: an existing ~/.ssh is not removed" {
  seed_existing_ssh_dir

  run_step AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  [ "$(cat "${FAKE_HOME}/.ssh/known_hosts")" = "stale-known-host" ]
  [ "$(cat "${FAKE_HOME}/.ssh/config")" = "Host stale" ]
}

@test "AC_REPOSITORY_SSH_KEY missing: skips even when AC_ENV_FILE_PATH is missing too" {
  run_step

  [ "$status" -eq 0 ]
  [ "$output" = "AC_REPOSITORY_SSH_KEY is not provided. Skipping step." ]
  [ -z "$stderr" ]
}

# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------

@test "happy path: exits 0 and logs every stage in order" {
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Create a file to save the RSA SSH private key" ]
  [ "${lines[1]}" = "Starting a new ssh-agent" ]
  [ "${lines[2]}" = "Agent pid 4242" ]
  [ "${lines[3]}" = "Add the SSH private key to the ssh-agent" ]
  [ "${lines[4]}" = "Identity added: ${FAKE_HOME}/.ssh/appcircle_ssh" ]
  [ "${lines[5]}" = "Exporting SSH_AUTH_SOCK=${STUB_SOCK}" ]
  [ "${#lines[@]}" -eq 6 ]
}

@test "happy path: writes the key verbatim to ~/.ssh/appcircle_ssh with mode 600" {
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  [ "$(cat "${FAKE_HOME}/.ssh/appcircle_ssh")" = "$TEST_KEY" ]
  # echo adds exactly one trailing newline, which ssh-add needs.
  [ "$(tail -c 1 "${FAKE_HOME}/.ssh/appcircle_ssh" | od -An -c | tr -d ' ')" = '\n' ]
  has_mode "${FAKE_HOME}/.ssh/appcircle_ssh" 600
}

@test "happy path: key with backslashes, spaces and quotes is written unchanged" {
  local key='line one \n not-a-newline "quoted" $NOT_EXPANDED'

  run_step AC_REPOSITORY_SSH_KEY="$key" AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  [ "$(cat "${FAKE_HOME}/.ssh/appcircle_ssh")" = "$key" ]
}

@test "happy path: writes ~/.ssh/config disabling StrictHostKeyChecking with mode 400" {
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  [ "$(cat "${FAKE_HOME}/.ssh/config")" = "$(printf 'Host *\n    StrictHostKeyChecking no')" ]
  has_mode "${FAKE_HOME}/.ssh/config" 400
}

@test "happy path: starts ssh-agent once and adds the key file with ssh-add" {
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  run cat "$CALLS"
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "ssh-agent " ]
  [ "${lines[1]}" = "ssh-add ${FAKE_HOME}/.ssh/appcircle_ssh [SSH_AUTH_SOCK=${STUB_SOCK}]" ]
}

@test "happy path: exports SSH_AUTH_SOCK to AC_ENV_FILE_PATH" {
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  [ "$(cat "$ENV_FILE")" = "SSH_AUTH_SOCK=${STUB_SOCK}" ]
}

@test "happy path: appends to an existing env file without touching earlier lines" {
  printf 'AC_FOO=bar\nAC_BAZ=qux\n' > "$ENV_FILE"

  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  run cat "$ENV_FILE"
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "AC_FOO=bar" ]
  [ "${lines[1]}" = "AC_BAZ=qux" ]
  [ "${lines[2]}" = "SSH_AUTH_SOCK=${STUB_SOCK}" ]
}

@test "happy path: an existing ~/.ssh is replaced, not appended to" {
  seed_existing_ssh_dir

  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  [ ! -e "${FAKE_HOME}/.ssh/known_hosts" ]
  [ "$(cat "${FAKE_HOME}/.ssh/appcircle_ssh")" = "$TEST_KEY" ]
  [ "$(cat "${FAKE_HOME}/.ssh/config")" = "$(printf 'Host *\n    StrictHostKeyChecking no')" ]
}

@test "happy path: running the step twice leaves a single key and config entry" {
  run_step AC_REPOSITORY_SSH_KEY="stale-key" AC_ENV_FILE_PATH="$ENV_FILE"
  [ "$status" -eq 0 ]
  # config is 0400 after the first run; the second run must still be able to replace it.
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  [ "$(cat "${FAKE_HOME}/.ssh/appcircle_ssh")" = "$TEST_KEY" ]
  [ "$(grep -c '^Host \*$' "${FAKE_HOME}/.ssh/config")" -eq 1 ]
}

@test "happy path: HOME without an existing .ssh directory is supported" {
  [ ! -e "${FAKE_HOME}/.ssh" ]

  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE"

  [ "$status" -eq 0 ]
  [ -d "${FAKE_HOME}/.ssh" ]
}

# ---------------------------------------------------------------------------
# AC_ENV_FILE_PATH (provided by the agent, not validated up front)
# ---------------------------------------------------------------------------

@test "AC_ENV_FILE_PATH missing: fails with non-zero exit after the key was added" {
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY"

  [ "$status" -ne 0 ]
  [[ "$stderr" == *"ambiguous redirect"* ]]
  [[ "$output" == *"Exporting SSH_AUTH_SOCK=${STUB_SOCK}"* ]]
  grep -q "^ssh-add " "$CALLS"
}

@test "AC_ENV_FILE_PATH empty: fails with non-zero exit after the key was added" {
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH=""

  [ "$status" -ne 0 ]
  [[ "$stderr" == *"ambiguous redirect"* ]]
  grep -q "^ssh-add " "$CALLS"
}

@test "AC_ENV_FILE_PATH in a missing directory: fails with non-zero exit" {
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="${WORK}/no/such/dir/env"

  [ "$status" -ne 0 ]
  [[ "$stderr" == *"No such file or directory"* ]]
  [ ! -e "${WORK}/no" ]
}

# ---------------------------------------------------------------------------
# External command failures
# ---------------------------------------------------------------------------

@test "ssh-add failure: stops the step before config and env file are written" {
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE" STUB_SSH_ADD_EXIT=1

  [ "$status" -eq 1 ]
  [[ "$stderr" == *"Error loading key \"${FAKE_HOME}/.ssh/appcircle_ssh\": invalid format"* ]]
  [[ "$output" != *"Exporting SSH_AUTH_SOCK"* ]]
  [ ! -e "${FAKE_HOME}/.ssh/config" ]
  [ ! -e "$ENV_FILE" ]
}

@test "ssh-add failure: its exit code is propagated" {
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE" STUB_SSH_ADD_EXIT=2

  [ "$status" -eq 2 ]
}

@test "ssh-agent failure: is not detected and an empty SSH_AUTH_SOCK is exported (current behaviour)" {
  run_step AC_REPOSITORY_SSH_KEY="$TEST_KEY" AC_ENV_FILE_PATH="$ENV_FILE" STUB_SSH_AGENT_EXIT=1

  # `eval $(ssh-agent)` evaluates an empty string, so `set -e` never sees the failure.
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"ssh-agent: stub failure"* ]]
  grep -q "^ssh-add ${FAKE_HOME}/.ssh/appcircle_ssh \[SSH_AUTH_SOCK=\]$" "$CALLS"
  [ "$(cat "$ENV_FILE")" = "SSH_AUTH_SOCK=" ]
}
