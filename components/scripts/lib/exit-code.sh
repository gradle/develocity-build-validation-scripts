#!/usr/bin/env bash

SUCCESS=0
INVALID_INPUT=1
BUILD_FAILED=2
BUILD_NOT_FULLY_CACHEABLE=3
PERFORMANCE_CHARACTERISTICS_UNKNOWN=4
UNEXPECTED_ERROR=100

readonly SUCCESS INVALID_INPUT UNEXPECTED_ERROR BUILD_FAILED BUILD_NOT_FULLY_CACHEABLE PERFORMANCE_CHARACTERISTICS_UNKNOWN

# Overrides the die() function loaded from the argbash-generated parsing libs
die() {
  local _ret="${2:-${UNEXPECTED_ERROR}}"
  printf "${ERROR_COLOR}%s${RESTORE}\n" "$1"
  if [[ "${_PRINT_HELP:-no}" == "yes" ]]; then
    print_bl
    print_help >&2
  fi
  exit "${_ret}"
}

exit_with_return_code() {
  if [[ " ${build_outcomes[*]} " =~ " FAILED " ]]; then
    exit "${BUILD_FAILED}"
  fi

  if [[ "${fail_if_not_fully_cacheable}" == "on" ]]; then
    if [[ -z "${executed_cacheable_num_tasks[1]}" ]]; then
      print_bl
      die "FAILURE: Unable to determine if build is fully cacheable: Performance characteristics are unknown and --fail-if-not-fully-cacheable was used." "${PERFORMANCE_CHARACTERISTICS_UNKNOWN}"
    fi

    local executed_avoidable_tasks
    executed_avoidable_tasks=$(( executed_cacheable_num_tasks[1] ))
    if (( executed_avoidable_tasks > 0 )); then
      print_bl
      if [[ "${BUILD_TOOL}" == "Maven" ]]; then
        die "FAILURE: Build is not fully cacheable for the given execution plan." "${BUILD_NOT_FULLY_CACHEABLE}"
      else
        die "FAILURE: Build is not fully cacheable for the given task graph." "${BUILD_NOT_FULLY_CACHEABLE}"
      fi
    fi
  fi
  exit "${SUCCESS}"
}
