#!/usr/bin/env bash

readonly BUILD_SCAN_SUPPORT_TOOL_JAR="${SCRIPT_DIR}/build-scan-support-tool.jar"
readonly GRADLE_ENTERPRISE_LICENSE="${SCRIPT_DIR}/gradle-enterprise.license"

build_scan_dumps=()

verify_offline_mode_required_files_exist() {
  if [ ! -f "$BUILD_SCAN_SUPPORT_TOOL_JAR" ]; then
    die "ERROR: Missing required file build-scan-support-tool.jar in the root folder of the build validation scripts" "${INVALID_INPUT}"
  fi
  if [ ! -f "$GRADLE_ENTERPRISE_LICENSE" ]; then
    die "ERROR: Missing required file gradle-enterprise.license in the root folder of the build validation scripts" "${INVALID_INPUT}"
  fi
}

find_and_read_build_scan_dumps() {
  find_build_scan_dumps
  read_build_scan_dumps
}

find_build_scan_dumps() {
  find_build_scan_dump "first"
  find_build_scan_dump "second"
}

find_build_scan_dump() {
  local build_name="$1"
  local build_dir="${EXP_DIR}/$build_name-build_${project_name}"
  if [ -n "${project_dir}" ]; then
    build_dir="$build_dir/$project_dir"
  fi
  build_scan_dump="$(find "$build_dir" -maxdepth 1 -type f -regex '^.*build-scan-.*-.*-.*-.*\.scan' | sort | tail -n 1)"
  if [ -z "$build_scan_dump" ]; then
    die "ERROR: No Build Scan dump found for the $build_name build"
  fi
  build_scan_dumps+=("${build_scan_dump}")
}

read_build_scan_dumps() {
  local build_scan_data args
  args=()

  args+=(
      "extract"
      "--license-file" "${SCRIPT_DIR}/gradle-enterprise.license"
      "0,${build_scan_dumps[0]}"
      "1,${build_scan_dumps[1]}"
  )

  echo "Extracting Build Scan data for all builds"
  if ! build_scan_data="$(invoke_java "$BUILD_SCAN_SUPPORT_TOOL_JAR" "${args[@]}")"; then
    exit "$UNEXPECTED_ERROR"
  fi
  echo "Finished extracting Build Scan data for all builds"

  parse_build_scans_and_build_time_metrics "$build_scan_data"
}
