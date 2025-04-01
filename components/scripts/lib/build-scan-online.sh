#!/usr/bin/env bash

readonly LOGGING_BRIEF='brief_logging'
readonly LOGGING_VERBOSE='verbose_logging'
readonly RUN_ID_NONE=''

# Main entrypoint for processing data online using the Build Scan summary tool.
# All scripts should call this function to fetch Build Scan data used in the
# experiment summary.
#
# USAGE:   fetch_build_scans_and_build_time_metrics <logging_level> <run_id>
# EXAMPLE: fetch_build_scans_and_build_time_metrics "$LOGGING_BRIEF" "$RUN_ID"
#
# <logging_level> should be set to the constant LOGGING_BRIEF or LOGGING_VERBOSE
# <run_id>        should be set to the constant RUN_ID or RUN_ID_NONE depending
#                 on whether the builds being queried for have a common run id,
#                 which will only be the case when both builds were produced
#                 during script execution
process_build_scan_data_online() {
  local logging_level="$1"
  local run_id="$2"

  # Always call since it will only read if the metadata file exists
  read_build_scan_metadata

  local build_scan_data
  build_scan_data="$(fetch_build_scan_data "$logging_level" "$run_id")"
  parse_build_scans_and_build_time_metrics "${build_scan_data}"
}

read_build_scan_metadata() {
  # This isn't the most robust way to read a CSV,
  # but we control the CSV so we don't have to worry about various CSV edge cases
  if [ -f "${BUILD_SCAN_FILE}" ]; then
    local build_scan_metadata
    build_scan_metadata=$(< "${BUILD_SCAN_FILE}")

    if [[ "${debug_mode}" == "on" ]]; then
      debug "Raw Build Scan metadata (build-scans.csv)"
      debug "---------------------------"
      debug "${build_scan_metadata}"
      debug ""
    fi

    local run_num project_name base_url build_scan_url build_scan_id

    # shellcheck disable=SC2034
    while IFS=, read -r run_num project_name base_url build_scan_url build_scan_id; do
       project_names[run_num]="${project_name}"
       base_urls[run_num]="${base_url}"
       build_scan_urls[run_num]="${build_scan_url}"
       build_scan_ids[run_num]="${build_scan_id}"
    done <<< "${build_scan_metadata}"
  fi
}

is_build_scan_metadata_missing() {
  if [ ! -f "${BUILD_SCAN_FILE}" ]; then
    return 0
  fi
  while IFS=, read -r run_num field_1 field_2 field_3; do
    if [[ "$run_num" == "$1"  ]]; then
      return 1
    fi
  done < "${BUILD_SCAN_FILE}"
  return 0
}

# Used by CI / Local experiments to fetch data for the first CI build.
fetch_single_build_scan() {
  local build_scan_url="$1"

  local build_scan_data
  build_scan_data="$(fetch_build_scan_data "$LOGGING_VERBOSE" "$RUN_ID_NONE")"

  parse_single_build_scan "${build_scan_data}"
}

# WARNING: Experiment scripts should not call this function directly and instead
#          use the process_build_scan_data_online or fetch_single_build_scan
#          function.
#
# WARNING: Callers of this function require stdout to be clean. No logging can
#          be done inside this function.
fetch_build_scan_data() {
  local logging_level="$1"
  local run_id="$2"

  if [[ "${debug_mode}" == "on" ]]; then
    args+=("--debug")
  fi

  if [ -n "${mapping_file}" ]; then
    args+=("--mapping-file" "${mapping_file}")
  fi

  if [ -f "${SCRIPT_DIR}/network.settings" ]; then
    args+=("--network-settings-file" "${SCRIPT_DIR}/network.settings")
  fi

  if [[ "${logging_level}" == "${LOGGING_BRIEF}" ]]; then
    args+=("--brief-logging")
  fi

  if [[ "${fail_if_not_fully_cacheable}" == "on" ]]; then
    args+=("--build-scan-availability-wait-timeout" "60")
  fi

  if [[ -n "${run_id}" ]]; then
    args+=("--experiment-run-id" "$run_id")
  fi

  for run_num in "${!build_scan_urls[@]}"; do
    args+=( "${run_num},${build_scan_urls[run_num]}" )
  done

  JAVA_HOME="${CLIENT_JAVA_HOME:-$JAVA_HOME}" invoke_java "${BUILD_SCAN_SUMMARY_JAR}:${SCRIPT_DIR}/lib/third-party/*" com.gradle.develocity.scans.summary.Main "${args[@]}"
}
