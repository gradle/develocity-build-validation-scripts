#!/usr/bin/env bash

# Arrays used by callers to access the fetched build scan data
project_names=()
base_urls=()
build_scan_urls=()
build_scan_ids=()
git_repos=()
git_branches=()
git_commit_ids=()
requested_tasks=()
build_outcomes=()
remote_build_cache_types=()
remote_build_cache_class_names=()
remote_build_cache_urls=()
remote_build_cache_shards=()

# Build caching performance metrics
avoided_up_to_date_num_tasks=()
avoided_up_to_date_avoidance_savings=()
avoided_from_cache_num_tasks=()
avoided_from_cache_avoidance_savings=()
executed_cacheable_num_tasks=()
executed_cacheable_duration=()
executed_not_cacheable_num_tasks=()
executed_not_cacheable_duration=()

# Build time metrics
initial_build_time=""
instant_savings=""
instant_savings_build_time=""
pending_savings=""
pending_savings_build_time=""

# Other build metrics
serialization_factors=()

parse_single_build_scan() {
  local build_scan_data="$1"

  debug_build_scan_data "$build_scan_data"

  local build_scan_rows

  # Parses build scan data to an array by line
  IFS=$'\n' read -rd '' -a build_scan_rows <<< "$build_scan_data"

  parse_build_scan_row "${build_scan_rows[1]}"
}

parse_build_scans_and_build_time_metrics() {
  local build_scan_data="$1"

  debug_build_scan_data "$build_scan_data"

  local build_scan_rows

  # Parses build scan data to an array by line
  IFS=$'\n' read -rd '' -a build_scan_rows <<< "$build_scan_data"

  parse_build_scan_row "${build_scan_rows[1]}"
  parse_build_scan_row "${build_scan_rows[2]}"

  parse_build_time_metrics "${build_scan_rows[4]}"
}

debug_build_scan_data() {
  local build_scan_data="$1"

  debug "Raw build scan data"
  debug "---------------------------"
  debug "${build_scan_data}"
  debug ""
}

# shellcheck disable=SC2034 # not all scripts use all of the fetched data
parse_build_scan_row() {
  local build_scan_row="$1"

  local run_num

  while IFS=, read -r run_num field_1 field_2 field_3 field_4 field_5 field_6 field_7 field_8 field_9 field_10 field_11 field_12 field_13 field_14 field_15 field_16 field_17 field_18 field_19 field_20 field_21 field_22; do
    debug "Build Scan $field_4 is for build $run_num"

    # The project_name should be overridden by Build Scan data if it is
    # available. This is so that the project names displayed in the summary are
    # consistent with what is shown in the Build Scan.

    if [ -n "${field_1}" ]; then
      project_names[run_num]="${field_1}"
    fi

    # If the following fields are already valued, then they should not be
    # overridden by Build Scan data. For locally executed builds, this data is
    # determined by the scripts as a result of execution.

    if [ -z "${base_urls[run_num]}" ]; then
      base_urls[run_num]="${field_2}"
    fi

    if [ -z "${build_scan_urls[run_num]}" ]; then
      build_scan_urls[run_num]="${field_3}"
    fi

    if [ -z "${build_scan_ids[run_num]}" ]; then
      build_scan_ids[run_num]="${field_4}"
    fi

    if [ -z "${git_repos[run_num]}" ]; then
      git_repos[run_num]="${field_5}"
    fi

    if [ -z "${git_branches[run_num]}" ]; then
      git_branches[run_num]="${field_6}"
    fi

    if [ -z "${git_commit_ids[run_num]}" ]; then
      git_commit_ids[run_num]="${field_7}"
    fi

    if [ -z "${requested_tasks[run_num]}" ]; then
      requested_tasks[run_num]="$(remove_clean_task "${field_8}")"
    fi

    if [ -z "${build_outcomes[run_num]}" ]; then
      build_outcomes[run_num]="${field_9}"
    fi

    # The below fields are always set by Build Scan data regardless of their
    # previous value and are always safe to override.

    remote_build_cache_types[run_num]="${field_10}"
    remote_build_cache_class_names[run_num]="${field_11}"
    remote_build_cache_urls[run_num]="${field_12}"
    remote_build_cache_shards[run_num]="${field_13}"

    # Build caching performance metrics
    avoided_up_to_date_num_tasks[run_num]="${field_14}"
    avoided_up_to_date_avoidance_savings[run_num]="${field_15}"
    avoided_from_cache_num_tasks[run_num]="${field_16}"
    avoided_from_cache_avoidance_savings[run_num]="${field_17}"
    executed_cacheable_num_tasks[run_num]="${field_18}"
    executed_cacheable_duration[run_num]="${field_19}"
    executed_not_cacheable_num_tasks[run_num]="${field_20}"
    executed_not_cacheable_duration[run_num]="${field_21}"

    # Other build metrics
    serialization_factors[run_num]="${field_22}"
  done <<< "${build_scan_row}"
}

# shellcheck disable=SC2034 # not all scripts use all of the fetched data
parse_build_time_metrics() {
  local build_time_metrics_row="$1"

  # Parses each build time metric to the corresponding global variable
  IFS=, read -r initial_build_time instant_savings instant_savings_build_time pending_savings pending_savings_build_time <<< "${build_time_metrics_row}"
}
