#!/usr/bin/env bash

invoke_gradle() {
  local run_num args
  args=()
  run_num=$1
  shift

  local original_dir
  if [ -n "${project_dir}" ]; then
    original_dir="$(pwd)"
    cd "${project_dir}" > /dev/null 2>&1 || die "ERROR: Subdirectory ${project_dir} (set with --project-dir) does not exist in ${project_name}" "${INVALID_INPUT}"
  fi

  args+=(
    --init-script "${INIT_SCRIPTS_DIR}/develocity-injection.gradle"
    --init-script "${INIT_SCRIPTS_DIR}/configure-build-validation.gradle"
    -Ddevelocity.injection.init-script-name=develocity-injection.gradle
    -Ddevelocity.injection-enabled=true
  )

  if [ "$enable_develocity" == "on" ]; then
    args+=(
      -Dgradle.plugin-repository.url=https://plugins.gradle.org/m2
      -Ddevelocity.plugin.version="3.14.1"
      -Ddevelocity.ccud-plugin.version="2.2.1"
    )
  fi

  if [ -n "${develocity_server}" ]; then
    args+=(
      -Ddevelocity.url="${develocity_server}"
      -Ddevelocity.enforce-url=true
      -Ddevelocity.allow-untrusted-server=false
    )
  fi

  args+=(
    -Ddevelocity.build-validation.expDir="${EXP_DIR}"
    -Ddevelocity.build-validation.expId="${EXP_SCAN_TAG}"
    -Ddevelocity.build-validation.runId="${RUN_ID}"
    -Ddevelocity.build-validation.runNum="${run_num}"
    -Ddevelocity.build-validation.scriptsVersion="${SCRIPT_VERSION}"
    -Ddevelocity.build-scan.upload-in-background=false
    -Ddevelocity.capture-file-fingerprints=true
    -Dpts.enabled=false
  )

  # https://stackoverflow.com/a/31485948
  while IFS= read -r -d ''; do
    local extra_arg="$REPLY"
    if [ -n "$extra_arg" ]; then
      args+=("$extra_arg")
    fi
  done < <(xargs printf '%s\0' <<<"$extra_args")

  args+=("$@")

  rm -f "${EXP_DIR}/errors.txt"

  debug "Current directory: $(pwd)"
  debug ./gradlew "${args[@]}"

  if ./gradlew "${args[@]}"; then
      build_outcomes+=("SUCCESSFUL")
  else
      build_outcomes+=("FAILED")
  fi

  if [ -f "${EXP_DIR}/errors.txt" ]; then
    print_bl
    die "ERROR: Experiment aborted due to a non-recoverable failure: $(cat "${EXP_DIR}/errors.txt")"
  fi

  if is_build_scan_metadata_missing "$run_num"; then
    print_bl
    die "ERROR: Experiment aborted due to a non-recoverable failure: No Build Scan was published"
  fi

  # defined in git.sh
  read_git_metadata_from_current_repo
  requested_tasks+=("${tasks}")

  if [ -n "${project_dir}" ]; then
    # shellcheck disable=SC2164 # We are just navigating back to the original directory
    cd "${original_dir}"
  fi
}

make_local_cache_dir() {
  rm -rf "${BUILD_CACHE_DIR}"
  mkdir -p "${BUILD_CACHE_DIR}"
}
