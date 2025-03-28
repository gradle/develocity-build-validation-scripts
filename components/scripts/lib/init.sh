#!/usr/bin/env bash

make_experiment_dir() {
  mkdir -p "${EXP_DIR}"
  cd "${EXP_DIR}" || die "Unable to access the experiment dir (${EXP_DIR})."

  make_symlink_to_latest_experiment_dir
}

make_symlink_to_latest_experiment_dir() {
  LINK_NAME="$(dirname "${EXP_DIR}")/latest"
  readonly LINK_NAME
  rm -f "${LINK_NAME}" > /dev/null 2>&1
  ln -s "${EXP_DIR}" "${LINK_NAME}" > /dev/null 2>&1
}

# Below is an explanation of what constitutes a 'run_id'.
#
#    0:     A static digit '1'
#    1-5:   A random number, left-padded with '0', then reversed
#    6-16:  The current number of seconds since epoch, truncated to 10 digits, then reversed
#    17-18: The experiment number
#
# When converted to hex, this creates a pseudorandom 15 digit value. The static
# '1' and number of seconds since epoch are truncated to ensure the value
# remains at 15 digits.
#
# The order of components is very intentional. With the exception of the static
# value at the beginning, the most significant digits are also the most
# variable. This gives the best illusion of "random".
#
# The 'run_id' does not need to be cryptographically secure, only random
# *enough* such that it's extremely unlikely that two identical 'run_id's will
# ever be generated. For a collision to occur, the same experiment number during
# the same second must generate the same random number. It is theoretically
# possible to have another chance for collision in the future since the number
# of seconds since epoch is truncated, but this is only possible once every ~317
# years.
generate_run_id() {
  local time_component rand_component
  time_component="$(printf "%.10s" "$(date +%s | rev)")"
  rand_component="$(rand=$RANDOM; printf '%05d' "$rand" | rev)"
  printf '%x' "1$rand_component$time_component${EXP_NO}"
}

# Init common constants
RUN_ID=$(generate_run_id)
readonly RUN_ID
EXP_DIR="${SCRIPT_DIR}/.data/${SCRIPT_NAME%.*}/$(date +"%Y%m%dT%H%M%S")-${RUN_ID}"
readonly EXP_DIR
RECEIPT_FILE="${EXP_DIR}/${EXP_SCAN_TAG}-$(date +"%Y%m%dT%H%M%S").receipt"
readonly RECEIPT_FILE
BUILD_SCAN_FILE="${EXP_DIR}/build-scans.csv"
readonly BUILD_SCAN_FILE
BUILD_CACHE_DIR="${EXP_DIR}/build-cache"
readonly BUILD_CACHE_DIR
BUILD_SCAN_SUMMARY_JAR="${SCRIPT_DIR}/lib/develocity/build-scan-summary-${SUMMARY_VERSION}.jar"
readonly BUILD_SCAN_SUMMARY_JAR

if [[ "${BUILD_TOOL}" == "Gradle" ]]; then
  BUILD_TOOL_TASK="task"
elif [[ "${BUILD_TOOL}" == "Maven" ]]; then
  BUILD_TOOL_TASK="goal"
fi
readonly BUILD_TOOL_TASK
