#!/usr/bin/env bash

readonly SUMMARY_FMT="%-33s%s"
readonly ORDINALS=( first second third fourth fifth sixth seventh eighth ninth tenth )

warnings=()

summary_row() {
  infof "${SUMMARY_FMT}" "$1" "${2:-${WARN_COLOR}<unknown>${RESTORE}}"
}

comparison_summary_row() {
  local header value
  header="$1"
  shift;

  if [[ "$1" == "$2" ]]; then
    value="$1"
  else
    value="${WARN_COLOR}${1:-<unknown>} | ${2:-<unknown>}${RESTORE}"
  fi

  summary_row "${header}" "${value}"
}

quick_link_row() {
  local header value unknown_tests unknown_values
  header="$1"
  shift
  value="$1"
  shift
  unknown_tests=("$@")

  mark_unknown=false
  for v in "${unknown_tests[@]}"; do
    [[ "$v" = "" ]] && mark_unknown=true
  done

  if [[ "${mark_unknown}" == "true" ]]; then
    summary_row "${header}" ""
  else
    summary_row "${header}" "$value"
  fi
}

print_bl() {
  if [[ "${debug_mode}" == "on" ]]; then
    debug "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  else
    echo
  fi
}

# Strips color codes from Standard in. This function is intended to be used as a filter on another command:
# print_summary | strip_color_codes
strip_color_codes() {
  # shellcheck disable=SC2001  # I could only get this to work with sed
  sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g'
}

# Reads and deduplicates the warning messages (only works as long as each message is a single line)
read_build_warnings() {
  if [[ "${build_outcomes[0]}" == "FAILED" ]]; then
    warnings+=("The first build failed. This may skew the outcome of the experiment.")
  fi
  if [[ "${build_outcomes[1]}" == "FAILED" ]]; then
    warnings+=("The second build failed. This may skew the outcome of the experiment.")
  fi

  local warnings_file
  warnings_file="${EXP_DIR}/warnings.txt"
  if [ -f "${warnings_file}" ]; then
    local warnings_file_content
    warnings_file_content=$(sort "${warnings_file}" | uniq)

    while read -r l; do
      warnings+=("$l")
    done <<< "${warnings_file_content}"
  fi
}

print_warnings() {
  read_build_warnings
  if [[ ${#warnings[@]} -gt 0 ]]; then
    print_bl
    for (( i=0; i<${#warnings[@]}; i++ )); do
      warn "${warnings[i]}"
    done
  fi
}

print_summary() {
  detect_warnings_from_build_scans

  info "Summary"
  info "-------"
  print_experiment_info
  print_experiment_specific_summary_info
  print_build_scans

  print_warnings

  print_performance_characteristics

  print_bl
  print_quick_links
}

detect_warnings_from_build_scans() {
  local unknown_values=false
  for (( i=0; i<2; i++ )); do
    if [ -z "${project_names[i]}" ] ||
       [ -z "${git_repos[i]}" ] ||
       [ -z "${git_branches[i]}" ] ||
       [ -z "${git_commit_ids[i]}" ] ||
       [ -z "${requested_tasks[i]}" ]; then
      unknown_values=true
    fi
    if [ -z "${build_outcomes[i]}" ]; then
      warnings+=("Failed to fetch build scan data for the ${ORDINALS[i]} build.")
    fi
    if [ "${remote_build_cache_types[i]}" == "unknown" ]; then
      # "Develocity Build Validation Scripts" is specifically mentioned as to
      # not imply Develocity itself does not work with other remote build cache
      # implementations.
      warnings+=("The ${ORDINALS[i]} build ran using a remote build cache implementation not officially supported by the Develocity Build Validation Scripts.")
    fi
  done

  local value_mismatch=false
  if [[ "${project_names[0]}" != "${project_names[1]}" ]] ||
     [[ "${git_repos[0]}" != "${git_repos[1]}" ]] ||
     [[ "${git_branches[0]}" != "${git_branches[1]}" ]] ||
     [[ "${git_commit_ids[0]}" != "${git_commit_ids[1]}" ]] ||
     [[ "${requested_tasks[0]}" != "${requested_tasks[1]}" ]] ||
     [[ "${remote_build_cache_urls[0]}" != "${remote_build_cache_urls[1]}" ]] ||
     [[ "${remote_build_cache_class_names[0]}" != "${remote_build_cache_class_names[1]}" ]]; then
    value_mismatch=true
  fi

  if [[ "${value_mismatch}" == "true" ]]; then
    warnings+=("Differences were detected between the two builds. This may skew the outcome of the experiment.")
  fi
  if [ "${remote_build_cache_urls[0]}" != "${remote_build_cache_urls[1]}" ]; then
    warnings+=("The two builds ran with different remote build cache URLs configured.")
  fi
  if [ "${remote_build_cache_class_names[0]}" != "${remote_build_cache_class_names[1]}" ]; then
    warnings+=("The two builds ran using different remote build cache implementations.")
  fi
  if [[ "${unknown_values}" == "true" ]]; then
    warnings+=("Some of the build properties could not be determined. This makes it uncertain if the experiment has run correctly.")
  fi
}

print_experiment_info() {
  comparison_summary_row "Project:" "${project_names[0]}" "${project_names[1]}"
  comparison_summary_row "Git repo:" "${git_repos[0]}" "${git_repos[1]}"
  comparison_summary_row "Git branch:" "${git_branches[0]}" "${git_branches[1]}"
  comparison_summary_row "Git commit id:" "${git_commit_ids[0]}" "${git_commit_ids[1]}"
  summary_row "Git options:" "${git_options}"
  summary_row "Project dir:" "${project_dir:-<root directory>}"
  comparison_summary_row "${BUILD_TOOL} ${BUILD_TOOL_TASK}s:" "${requested_tasks[0]}" "${requested_tasks[1]}"
  summary_row "${BUILD_TOOL} arguments:" "${extra_args:-<none>}"
  summary_row "Experiment:" "${EXP_NO} ${EXP_NAME}"
  summary_row "Experiment id:" "${EXP_SCAN_TAG}"
  if [[ "${SHOW_RUN_ID}" == "true" ]]; then
    summary_row "Experiment run id:" "${RUN_ID}"
  fi
  summary_row "Experiment artifact dir:" "$(relative_path "${SCRIPT_DIR}" "${EXP_DIR}")"
}

print_experiment_specific_summary_info() {
  # this function is intended to be overridden by experiments as-needed
  # have one command to satisfy shellcheck
  true
}

# This function is responsible for printing the "Performance Characteristics"
# section of the experiment summary.
#
# Experiments may override this function to include only relevant metrics.
print_performance_characteristics() {
  print_performance_characteristics_header

  print_build_time_metrics

  print_build_caching_leverage_metrics

  print_serialization_factor

  print_executed_cacheable_tasks_warning

  print_performance_characteristics_footer
}

print_performance_characteristics_header() {
  print_bl
  info "Performance Characteristics"
  info "---------------------------"
}

print_build_time_metrics() {
  local build_time_padding
  build_time_padding=$(max_length \
    "${initial_build_time}" \
    "${instant_savings_build_time}" \
    "${pending_savings_build_time}")

  print_initial_build_time "${build_time_padding}"

  print_build_time_with_instant_savings "${build_time_padding}"

  print_build_time_with_pending_savings "${build_time_padding}"
}

print_initial_build_time() {
  local value
  if [[ -n "${initial_build_time}" ]]; then
    printf -v value "%$1s" "${initial_build_time}"
  fi
  summary_row "Initial build time:" "${value}"
}

print_build_time_with_instant_savings() {
  local value
  if [[ -n "${instant_savings_build_time}" && -n "${instant_savings}" ]]; then
    printf -v value "%$1s, %s savings" "${instant_savings_build_time}" "${instant_savings}"
  fi
  summary_row "Build time with instant savings:" "${value}"
}

print_build_time_with_pending_savings() {
  local value
  if [[ -n "${pending_savings_build_time}" && -n "${pending_savings}" ]]; then
    printf -v value "%$1s, %s additional savings" "${pending_savings_build_time}" "${pending_savings}"
  fi
  summary_row "Build time with pending savings:" "${value}"
}

print_build_caching_leverage_metrics() {
  local task_count_padding
  task_count_padding=$(max_length \
    "${avoided_from_cache_num_tasks[1]}" \
    "${executed_cacheable_num_tasks[1]}" \
    "${executed_not_cacheable_num_tasks[1]}")

  print_avoided_cacheable_tasks "${task_count_padding}"

  print_executed_cacheable_tasks "${task_count_padding}"

  print_executed_non_cacheable_tasks "${task_count_padding}"
}

print_avoided_cacheable_tasks() {
  local value
  if [[ -n "${avoided_from_cache_num_tasks[1]}" && -n "${avoided_from_cache_avoidance_savings[1]}" ]]; then
    printf -v value "%$1s %ss, %s total saved execution time" \
      "${avoided_from_cache_num_tasks[1]}" \
      "${BUILD_TOOL_TASK}" \
      "${avoided_from_cache_avoidance_savings[1]}"
  fi
  summary_row "Avoided cacheable ${BUILD_TOOL_TASK}s:" "${value}"
}

print_executed_cacheable_tasks() {
  local value
  if [[ -n "${executed_cacheable_num_tasks[1]}" && -n "${executed_cacheable_duration[1]}" ]]; then
    local summary_color
    if (( executed_cacheable_num_tasks[1] > 0)); then
      summary_color="${WARN_COLOR}"
    fi

    printf -v value "${summary_color}%$1s %ss, %s total execution time${RESTORE}" \
      "${executed_cacheable_num_tasks[1]}" \
      "${BUILD_TOOL_TASK}" \
      "${executed_cacheable_duration[1]}"
  fi
  summary_row "Executed cacheable ${BUILD_TOOL_TASK}s:" "${value}"
}

print_executed_non_cacheable_tasks() {
  local value
  if [[ -n "${executed_not_cacheable_num_tasks[1]}" && -n "${executed_not_cacheable_duration[1]}" ]]; then
    printf -v value "%$1s %ss, %s total execution time" \
      "${executed_not_cacheable_num_tasks[1]}" \
      "${BUILD_TOOL_TASK}" \
      "${executed_not_cacheable_duration[1]}"
  fi
  summary_row "Executed non-cacheable ${BUILD_TOOL_TASK}s:" "${value}"
}

print_serialization_factor() {
  local value
  if [[ -n "${serialization_factors[0]}" && -n "${serialization_factors[1]}" ]]; then
    printf -v value "%s first build, %s second build" "${serialization_factors[0]}" "${serialization_factors[1]}"
  fi
  summary_row "Serialization factor:" "${value}"
}

print_executed_cacheable_tasks_warning() {
  if (( executed_cacheable_num_tasks[1] > 0)); then
    print_bl
    warn "Not all cacheable ${BUILD_TOOL_TASK}s' outputs were taken from the build cache in the second build. This reduces the savings in ${BUILD_TOOL_TASK} execution time."
  fi
}

print_performance_characteristics_footer() {
  print_bl
  info "See $(performance_characteristics_link) for details."
}

performance_characteristics_link() {
  if [[ "${BUILD_TOOL}" == "Maven" ]]; then
    echo "https://gradle.com/bvs/main/Maven.md#performance-characteristics"
  else
    echo "https://gradle.com/bvs/main/Gradle.md#performance-characteristics"
  fi
}

print_quick_links() {
  if [[ "${BUILD_TOOL}" == "Gradle" ]]; then
    print_gradle_quick_links
  else
    print_maven_quick_links
  fi
}

print_gradle_quick_links() {
  info "Investigation Quick Links"
  info "-------------------------"
  quick_link_row "Task execution overview:" "${base_urls[1]}/s/${build_scan_ids[1]}/performance/execution" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Executed tasks timeline:" "${base_urls[1]}/s/${build_scan_ids[1]}/timeline?outcome=success,failed&sort=longest" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Avoided cacheable tasks:" "${base_urls[1]}/s/${build_scan_ids[1]}/timeline?outcome=from-cache&sort=longest" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Executed cacheable tasks:" "${base_urls[1]}/s/${build_scan_ids[1]}/timeline?cacheability=cacheable,overlapping-outputs,validation-failure&outcome=success,failed&sort=longest" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Executed non-cacheable tasks:" "${base_urls[1]}/s/${build_scan_ids[1]}/timeline?cacheability=any-non-cacheable,not:overlapping-outputs,not:validation-failure&outcome=success,failed&sort=longest" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Build caching statistics:" "${base_urls[1]}/s/${build_scan_ids[1]}/performance/build-cache" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Task inputs comparison:" "${base_urls[1]}/c/${build_scan_ids[0]}/${build_scan_ids[1]}/task-inputs?cacheability=cacheable,overlapping-outputs,validation-failure" "${base_urls[1]}" "${build_scan_ids[0]}" "${build_scan_ids[1]}"
}

print_maven_quick_links() {
  info "Investigation Quick Links"
  info "-------------------------"
  quick_link_row "Goal execution overview:" "${base_urls[0]}/s/${build_scan_ids[1]}/performance/execution" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Executed goals timeline:" "${base_urls[0]}/s/${build_scan_ids[1]}/timeline?outcome=success,failed&sort=longest" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Avoided cacheable goals:" "${base_urls[0]}/s/${build_scan_ids[1]}/timeline?outcome=from-cache&sort=longest" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Executed cacheable goals:" "${base_urls[0]}/s/${build_scan_ids[1]}/timeline?cacheability=cacheable&outcome=success,failed&sort=longest" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Executed non-cacheable goals:" "${base_urls[0]}/s/${build_scan_ids[1]}/timeline?cacheability=any-non-cacheable&outcome=success,failed&sort=longest" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Build caching statistics:" "${base_urls[0]}/s/${build_scan_ids[1]}/performance/build-cache" "${base_urls[1]}" "${build_scan_ids[1]}"
  quick_link_row "Goal inputs comparison:" "${base_urls[0]}/c/${build_scan_ids[0]}/${build_scan_ids[1]}/goal-inputs?cacheability=cacheable" "${base_urls[1]}" "${build_scan_ids[0]}" "${build_scan_ids[1]}"
}

max_length() {
  local max_len

  max_len=${#1}
  shift

  for x in "${@}"; do
    if (( ${#x} > max_len )); then
      max_len=${#x}
    fi
  done

  echo "${max_len}"
}

warn_if_nonzero() {
  local value
  value=$1
  if (( value > 0 )); then
    echo "${WARN_COLOR}${value}${RESTORE}"
  else
    echo "$value"
  fi
}

print_build_scans() {
  for (( i=0; i<2; i++ )); do
    if [ -z "${build_outcomes[i]}" ]; then
      summary_row "Build scan ${ORDINALS[i]} build:" "${WARN_COLOR}${build_scan_urls[i]:+${build_scan_urls[i]} }BUILD SCAN DATA FETCH FAILED${RESTORE}"
    elif [[ "${build_outcomes[i]}" == "FAILED" ]]; then
      summary_row "Build scan ${ORDINALS[i]} build:" "${WARN_COLOR}${build_scan_urls[i]:+${build_scan_urls[i]} }FAILED${RESTORE}"
    else
      summary_row "Build scan ${ORDINALS[i]} build:" "${build_scan_urls[i]}"
    fi
  done
}

create_receipt_file() {
  {
  print_summary | strip_color_codes
  print_bl
  print_command_to_repeat_experiment | strip_color_codes
  print_bl
  echo "Generated by $(print_version)"
  } > "${RECEIPT_FILE}"
}
