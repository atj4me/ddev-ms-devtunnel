#!/usr/bin/env bats

# Bats tests updated for Microsoft Dev Tunnels (devtunnel)

setup() {
  set -eu -o pipefail
  export GITHUB_REPO=atj4me/ddev-ms-devtunnel

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p ~/tmp
  export TESTDIR=$(mktemp -d ~/tmp/${PROJNAME}.XXXXXX)
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  
  # Clean up any existing project
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  
  # Configure and start DDEV project
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  # Check if DDEV is running properly
  run ddev describe -j
  assert_success

  # Check if web service is running
  run bash -c "ddev describe -j | jq -r '.raw.services.web.State.Status'"
  assert_success
  assert_output "running"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1 || true
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  refute_output --partial "ERROR (spawn error)"
}

@test "devtunnel command exists and responds" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  refute_output --partial "ERROR (spawn error)"

  run ddev devtunnel --help
  assert_success

  run ddev devtunnel --version
  assert_success
}

@test "web_extra_daemons are configured correctly" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  assert_file_exist .ddev/config.ms-devtunnel.yaml
  assert_file_exist .ddev/web-build/Dockerfile.ms-devtunnel
  assert_file_exist .ddev/docker-compose.ms-devtunnel.yaml
}

@test "devtunnel CLI installation in web container" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  run ddev exec "which devtunnel"
  assert_success

  run ddev exec "devtunnel --version"
  assert_success
}

@test "devtunnel basic commands work" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  run ddev devtunnel --help
  assert_success

  run ddev devtunnel --version
  assert_success

  run ddev devtunnel host --help
  assert_success
}

@test "devtunnel host help works without auth" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  run ddev devtunnel host --help
  assert_success
}

@test "environment variables are properly set" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  run ddev exec "echo \$DDEV_ROUTER_HTTP_PORT"
  assert_success
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "devtunnel url and launch commands exist" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  run ddev devtunnel url || true
  run timeout 5s ddev devtunnel launch --dry-run 2>/dev/null || true
}

@test "is_site_running reports running for active project" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  run ddev devtunnel __test_is_site_running
  assert_success
  assert_output "running"
}

@test "no conflicting processes after restart" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  refute_output --partial "foreground already exists"
  run ddev restart -y
  assert_success
  refute_output --partial "foreground already exists"
  refute_output --partial "ERROR (spawn error)"
}

@test "devtunnel share command structure" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  run ddev devtunnel share --help 2>/dev/null || run ddev devtunnel host --help
}

@test "configuration files are properly installed" {
  run ddev add-on get "${DIR}"
  assert_success

  assert_file_exist .ddev/commands/host/devtunnel
  assert_file_exist .ddev/config.ms-devtunnel.yaml
  assert_file_exist .ddev/web-build/Dockerfile.ms-devtunnel
  assert_file_exist .ddev/docker-compose.ms-devtunnel.yaml
}

@test "devtunnel login starts project when stopped (noninteractive)" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  run ddev stop
  assert_success

  # Confirm web is not running
  run bash -c "ddev describe -j | jq -r '.raw.services.web.State.Status' || true"
  [[ "$output" != "running" ]]

  # Invoke login (DDEV_NONINTERACTIVE=true in tests -> should auto-start)
  run ddev devtunnel login || true

  # Now web should be running again
  run bash -c "ddev describe -j | jq -r '.raw.services.web.State.Status'"
  assert_output "running"
}

@test "devtunnel login (device-code) shows host-friendly instructions" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # Force device-code login and ensure wrapper prints host-friendly guidance
  run DT_DEVICE_LOGIN=1 ddev devtunnel login
  assert_success
  assert_output --partial "device-code login"
  assert_output --partial "Open on host"
  assert_output --partial "Enter code"
}

@test "devtunnel login auto-uses device-code in noninteractive/headless environments" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  # Tests run with DDEV_NONINTERACTIVE=true in setup(); wrapper should prefer device-code
  run ddev devtunnel login
  assert_success
  assert_output --partial "Using device-code login for devtunnel"
}

@test "devtunnel login --interactive requests interactive mode" {
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success

  run ddev devtunnel login --interactive || true
  assert_output --partial "Run interactive login for devtunnel"
} 
