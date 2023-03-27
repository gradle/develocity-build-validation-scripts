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
# shellcheck disable=SC2034 # not all scripts use this data
remote_build_cache_urls=()
# shellcheck disable=SC2034 # not all scripts use this data
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

# Build duration metrics
build_time=()
serialization_factors=()

initial_build_time=""
instant_savings=""
instant_savings_build_time=""
pending_savings=""
pending_savings_build_time=""

# shellcheck disable=SC2034 # not all scripts use all of the fetched data
parse_build_scan_csv() {
  # This isn't the most robust way to read a CSV,
  # but we control the CSV so we don't have to worry about various CSV edge cases

  local header_row_read run_num build_scan_csv
  local build_cache_metrics_only="$2"

  build_scan_csv="$(echo "$1" | tail -n 3 | head -n 2)"

  debug "Raw build scan data"
  debug "---------------------------"
  debug "${build_scan_csv}"
  debug ""

  while IFS=, read -r run_num field_1 field_2 field_3 field_4 field_5 field_6 field_7 field_8 field_9 field_10 field_11 field_12 field_13 field_14 field_15 field_16 field_17 field_18 field_19 field_20 field_21; do
    debug "Build Scan $field_4 is for build $run_num"
    project_names[run_num]="$field_1"
    build_scan_ids[run_num]="$field_4"

    if [[ "$build_cache_metrics_only" != "build_cache_metrics_only" ]]; then
      base_urls[run_num]="$field_2"
      build_scan_urls[run_num]="$field_3"
      git_repos[run_num]="$field_5"
      git_branches[run_num]="$field_6"
      git_commit_ids[run_num]="$field_7"
      requested_tasks[run_num]="$(remove_clean_task "${field_8}")"
      build_outcomes[run_num]="$field_9"
      remote_build_cache_urls[run_num]="${field_10}"
      remote_build_cache_shards[run_num]="${field_11}"
    fi

    # Build caching performance metrics
    avoided_up_to_date_num_tasks[run_num]="${field_12}"
    avoided_up_to_date_avoidance_savings[run_num]="${field_13}"
    avoided_from_cache_num_tasks[run_num]="${field_14}"
    avoided_from_cache_avoidance_savings[run_num]="${field_15}"
    executed_cacheable_num_tasks[run_num]="${field_16}"
    executed_cacheable_duration[run_num]="${field_17}"
    executed_not_cacheable_num_tasks[run_num]="${field_18}"
    executed_not_cacheable_duration[run_num]="${field_19}"

    # Build time metrics
    build_time[run_num]="${field_20}"
    serialization_factors[run_num]="${field_21}"
  done <<< "${build_scan_csv}"

  initial_build_time="$(calculate_initial_build_time)"
  instant_savings="$(calculate_instant_savings)"
  instant_savings_build_time="$(calculate_instant_savings_build_time)"
  pending_savings="$(calculate_pending_savings)"
  pending_savings_build_time="$(calculate_pending_savings_build_time)"
}

# The initial_build_time is the build time of the first build.
calculate_initial_build_time() {
  if [[ -n "${build_time[0]}" ]]; then
    echo "${build_time[0]}"
  fi
}

# The instant_savings is the difference in the wall-clock build time between
# the first and second build.
calculate_instant_savings() {
  if [[ -n "${build_time[0]}" && -n "${build_time[1]}" ]]; then
    echo "$((build_time[0]-build_time[1]))"
  fi
}

# The instant_savings_build_time is the build time of the second build.
calculate_instant_savings_build_time() {
  if [[ -n "${build_time[1]}" ]]; then
    echo "${build_time[1]}"
  fi
}

# The pending_savings is an estimation of the savings if all cacheable tasks had
# been avoided.
calculate_pending_savings() {
  if [[ -n "${executed_cacheable_duration[1]}" && -n "${serialization_factors[1]}" ]]; then
    echo "${executed_cacheable_duration[1]}/${serialization_factors[1]}" | bc
  fi
}

# The pending_savings_build_time is an estimation of the build time if all
# cacheable tasks had been avoided.
calculate_pending_savings_build_time() {
  if [[ -n "${build_time[1]}" && -n "${pending_savings}" ]]; then
    echo "$((build_time[1]-pending_savings))"
  fi
}
