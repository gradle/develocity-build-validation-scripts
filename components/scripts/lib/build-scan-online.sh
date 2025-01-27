#!/usr/bin/env bash

# This is a helper function for the common pattern of reading Build Scan metadata
# from the build-scans.csv file, then retrieving build metrics using the
# Develocity API.
process_build_scan_data_online() {
  read_build_scan_metadata
  fetch_build_scans_and_build_time_metrics 'brief_logging' "${build_scan_urls[@]}"
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

fetch_single_build_scan() {
  local build_scan_url="$1"

  local build_scan_data
  build_scan_data="$(fetch_build_scan_data 'verbose_logging' "${build_scan_url}")"

  parse_single_build_scan "${build_scan_data}"
}

# The value of logging_level should be either 'brief_logging' or
# 'verbose_logging'
fetch_build_scans_and_build_time_metrics() {
  local logging_level="$1"
  shift
  local build_scan_urls=("$@")

  if [[ "${logging_level}" == 'verbose_logging' ]]; then
    info "Fetching build scan data"
  fi

  local build_scan_data
  build_scan_data="$(fetch_build_scan_data "${logging_level}" "${build_scan_urls[@]}")"

  parse_build_scans_and_build_time_metrics "${build_scan_data}"
}

# Note: Callers of this function require stdout to be clean. No logging can be
#       done inside this function.
fetch_build_scan_data() {
  local logging_level="$1"
  shift
  local build_scan_urls=("$@")

  if [[ "${debug_mode}" == "on" ]]; then
    args+=("--debug")
  fi

  if [ -n "${mapping_file}" ]; then
    args+=("--mapping-file" "${mapping_file}")
  fi

  if [ -f "${SCRIPT_DIR}/network.settings" ]; then
    args+=("--network-settings-file" "${SCRIPT_DIR}/network.settings")
  fi

  if [[ "${logging_level}" == "brief_logging" ]]; then
    args+=("--brief-logging")
  fi

  if [[ "${fail_if_not_fully_cacheable}" == "on" ]]; then
    args+=("--build-scan-availability-wait-timeout" "60")
  fi

  for run_num in "${!build_scan_urls[@]}"; do
    args+=( "${run_num},${build_scan_urls[run_num]}" )
  done

  JAVA_HOME="${CLIENT_JAVA_HOME:-$JAVA_HOME}" invoke_java "${BUILD_SCAN_SUMMARY_JAR}:${SCRIPT_DIR}/lib/third-party/*" com.gradle.develocity.scans.summary.Main "${args[@]}"
}
