#!/usr/bin/env bash
#
# Runs Experiment 01 - Validate Maven Local Build Caching - Same project location
#
# Invoke this script with --help to get a description of the command line arguments
#
readonly EXP_NAME="Validate local build caching - same project location"
readonly EXP_DESCRIPTION="Validating that a Maven build is optimized for local build caching when invoked from the same location"
readonly EXP_NO="01"
readonly EXP_SCAN_TAG=exp1-maven
readonly BUILD_TOOL="Maven"
readonly SCRIPT_VERSION="<HEAD>"
readonly SUMMARY_VERSION="<SUMMARY_VERSION>"
readonly SHOW_RUN_ID=true

# Needed to bootstrap the script
SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_NAME
# shellcheck disable=SC2164  # it is highly unlikely cd will fail here because we're cding to the location of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; cd -P "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo .)")"; pwd)"
readonly SCRIPT_DIR
readonly LIB_DIR="${SCRIPT_DIR}/lib/scripts"

# Include and parse the command line arguments
# shellcheck source=lib/scripts/01-cli-parser.sh
source "${LIB_DIR}/${EXP_NO}-cli-parser.sh" || { echo -e "\033[00;31m\033[1mERROR: Couldn't find '${LIB_DIR}/${EXP_NO}-cli-parser.sh'\033[0m"; exit 100; }
# shellcheck source=lib/scripts/libs.sh
source "${LIB_DIR}/libs.sh" || { echo -e "\033[00;31m\033[1mERROR: Couldn't find '${LIB_DIR}/libs.sh'\033[0m"; exit 100; }

# These will be set by the config functions (see lib/config.sh)
git_repo=''
project_name=''
git_branch=''
project_dir=''
tasks=''
extra_args=''
enable_develocity=''
develocity_server=''
interactive_mode=''

main() {
  if [ "${interactive_mode}" == "on" ]; then
    wizard_execute
  else
    execute
  fi
  create_receipt_file
  exit_with_return_code
}

execute() {
  make_experiment_dir
  make_local_cache_dir
  git_checkout_project "build_${project_name}"

  print_bl
  execute_first_build
  copy_project_dir "build_${project_name}" "first-build_${project_name}" quietly

  print_bl
  execute_second_build
  rename_project_dir "build_${project_name}" "second-build_${project_name}"

  print_bl
  process_build_scan_data

  print_bl
  print_summary
}

wizard_execute() {
  print_introduction

  print_bl
  explain_prerequisites_ccud_maven_extension "I."

  print_bl
  explain_prerequisites_api_access "II."

  print_bl
  explain_collect_git_details
  print_bl
  collect_git_details

  print_bl
  explain_collect_maven_details
  print_bl
  collect_maven_details
  explain_command_to_repeat_experiment_after_collecting_parameters

  print_bl
  explain_clone_project
  print_bl
  make_experiment_dir
  make_local_cache_dir
  git_checkout_project "build_${project_name}"

  print_bl
  explain_first_build
  print_bl
  execute_first_build
  copy_project_dir "build_${project_name}" "first-build_${project_name}" quietly

  print_bl
  explain_second_build
  print_bl
  execute_second_build
  rename_project_dir "build_${project_name}" "second-build_${project_name}"

  print_bl
  explain_measure_build_results
  print_bl
  process_build_scan_data
  print_bl
  explain_and_print_summary
}

execute_first_build() {
  info "Running first build:"
  execute_build 0
}

execute_second_build() {
  info "Running second build:"
  execute_build 1
}

execute_build() {
  local run_num
  run_num="$1"
  shift

  print_maven_command

  #shellcheck disable=SC2086  # we actually want ${tasks} to expand because it may have more than one maven goal
  invoke_maven "${run_num}" \
     -Dgradle.cache.local.enabled=true \
     -Dgradle.cache.local.storeEnabled=true \
     -Dgradle.cache.local.directory="${BUILD_CACHE_DIR}" \
     -Dgradle.cache.remote.enabled=false \
     -Ddevelocity.cache.local.enabled=true \
     -Ddevelocity.cache.local.storeEnabled=true \
     -Ddevelocity.cache.local.directory="${BUILD_CACHE_DIR}" \
     -Ddevelocity.cache.remote.enabled=false \
     clean ${tasks}
}

print_maven_command() {
   info "./mvnw -Dscan -Dscan.tag.${EXP_SCAN_TAG} -Dscan.value.runId=${RUN_ID} -Dpts.enabled=false clean ${tasks}$(print_extra_args)"
 }

process_build_scan_data() {
  process_build_scan_data_online "$LOGGING_BRIEF" "$RUN_ID"
}

print_introduction() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_introduction_title)

In this experiment, you will validate how well a given project leverages
Develocity’s local build caching functionality when running the build in
the same location. A build is considered fully cacheable if it can be invoked
twice in a row with build caching enabled and, during the second invocation,
all cacheable goals avoid performing any work because:

  * The cacheable goals’ inputs have not changed since their last invocation and
  * The cacheable goals’ outputs are present in the local build cache and
  * No cacheable goals were excluded from build caching to ensure correctness

The experiment will reveal goals with volatile inputs, for example goals that
contain a timestamp in one of their inputs. It will also reveal goals that produce
non-deterministic outputs consumed by cacheable goals downstream, for example
goals generating code with non-deterministic method ordering or goals producing
artifacts that include timestamps.

The experiment will assist you to first identify those goals whose outputs are
not taken from the local build cache due to changed inputs or to ensure
correctness of the build, to then make an informed decision which of those
goals are worth improving to make your build faster, to then investigate why
they are not taken from the local build cache, and to finally fix them once you
understand the root cause.

The experiment can be run on any developer’s machine. It logically consists of
the following steps:

  1. Enable only local build caching and use an empty local build cache
  2. Run the build with a typical goal invocation including the ‘clean’ goal
  3. Run the build with the same goal invocation including the ‘clean’ goal
  4. Determine which cacheable goals are still executed in the second run and why
  5. Assess which of the executed, cacheable goals are worth improving
  6. Fix identified goals

The script you have invoked automates the execution of step 1, step 2, and step 3
without modifying the project. Build scans support your investigation in step 4
and step 5.

After improving the build to make it better leverage the local build cache,
you can push your changes and run the experiment again. This creates a cycle
of run → measure → improve → run.

${USER_ACTION_COLOR}Press <Enter> to get started with the experiment.${RESTORE}
EOF

  print_interactive_text "${text}"
  wait_for_enter
}

explain_first_build() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_separator)
${HEADER_COLOR}Run first build${RESTORE}

Now that the project has been checked out, the first build can be run with the
given Maven goals. The build will be invoked with the ‘clean’ goal included and
local build caching enabled. An empty local build cache will be used.

${USER_ACTION_COLOR}Press <Enter> to run the first build of the experiment.${RESTORE}
EOF
  print_interactive_text "${text}"
  wait_for_enter
}

explain_second_build() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_separator)
${HEADER_COLOR}Run second build${RESTORE}

Now that the first build has finished successfully, the second build can be run
with the same Maven goals. The build will again be invoked with the ‘clean’
goal included and local build caching enabled. The local build cache populated
during the first build will be used.

${USER_ACTION_COLOR}Press <Enter> to run the second build of the experiment.${RESTORE}
EOF
  print_interactive_text "$text"
  wait_for_enter
}

explain_measure_build_results() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_separator)
${HEADER_COLOR}Measure build results${RESTORE}

Now that the second build has finished successfully, you are ready to measure in
Develocity how well your build leverages Develocity's local build caching
functionality for the invoked set of Maven goals.

Some of the build scan data will be fetched from the build scans produced by the
two builds to assist you in your investigation.

${USER_ACTION_COLOR}Press <Enter> to measure the build results.${RESTORE}
EOF
  print_interactive_text "${text}"
  wait_for_enter
}

explain_and_print_summary() {
  local text
  IFS='' read -r -d '' text <<EOF
The ‘Summary’ section below captures the configuration of the experiment and the
two build scans that were published as part of running the experiment. The build
scan of the second build is particularly interesting since this is where you can
inspect what goals were not leveraging the local build cache.

$(explain_performance_characteristics)

The ‘Investigation Quick Links’ section below allows quick navigation to the
most relevant views in build scans to investigate what goals were avoided due to
local build caching and what goals executed in the second build, which of those
goals had the biggest impact on build performance, and what caused those goals
to not be taken from the local build cache.

$(explain_command_to_repeat_experiment)

$(print_summary)

$(print_command_to_repeat_experiment)

$(explain_when_to_rerun_experiment)
EOF
  print_interactive_text "${text}"
}

explain_performance_characteristics() {
  local text
  IFS='' read -r -d '' text <<EOF
The ‘Performance Characteristics’ section below reveals the realized and
potential savings from build caching. All cacheable goals' outputs need to be
taken from the build cache in the second build for the build to be fully
cacheable.
EOF
  echo -n "${text}"
}

process_args "$@"
main
