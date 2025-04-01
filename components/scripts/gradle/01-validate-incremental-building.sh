#!/usr/bin/env bash
#
# Runs Experiment 01 - Validate incremental building
#
# Invoke this script with --help to get a description of the command line arguments
#
readonly EXP_NAME="Validate incremental building"
readonly EXP_DESCRIPTION="Validating that a Gradle build is optimized for incremental building"
readonly EXP_NO="01"
readonly EXP_SCAN_TAG=exp1-gradle
readonly BUILD_TOOL="Gradle"
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
readonly INIT_SCRIPTS_DIR="${LIB_DIR}/gradle-init-scripts"

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
  explain_prerequisites_ccud_gradle_plugin "I."

  print_bl
  explain_prerequisites_api_access "II."

  print_bl
  explain_collect_git_details
  print_bl
  collect_git_details

  print_bl
  explain_collect_gradle_details
  print_bl
  collect_gradle_details
  explain_command_to_repeat_experiment_after_collecting_parameters

  print_bl
  explain_clone_project
  print_bl
  make_experiment_dir
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

# shellcheck disable=SC2086 # splitting expected
execute_first_build() {
  info "Running first build:"
  execute_build 0 clean ${tasks}
}

# shellcheck disable=SC2086 # splitting expected
execute_second_build() {
  info "Running second build:"
  execute_build 1 ${tasks}
}

execute_build() {
  local run_num
  run_num="$1"
  shift

  print_gradle_command "$@"
  invoke_gradle "${run_num}" --no-build-cache "$@"
}

print_gradle_command() {
    info "./gradlew --no-build-cache -Dscan.tag.${EXP_SCAN_TAG} -Dscan.value.runId=${RUN_ID} -Dpts.enabled=false $*$(print_extra_args)"
}

process_build_scan_data() {
  process_build_scan_data_online "$LOGGING_BRIEF" "$RUN_ID"
}

# Overrides summary.sh#print_performance_characteristics
print_performance_characteristics() {
  print_performance_characteristics_header

  print_build_time_metrics

  print_serialization_factor

  print_performance_characteristics_footer
}

# Overrides summary.sh#print_build_time_metrics
print_build_time_metrics() {
  local build_time_padding
  build_time_padding=$(max_length \
    "${initial_build_time}" \
    "${instant_savings_build_time}")

  print_initial_build_time "${build_time_padding}"

  print_build_time_with_instant_savings "${build_time_padding}"
}

# Overrides summary.sh#print_quick_links
print_quick_links() {
  info "Investigation Quick Links"
  info "-------------------------"
  summary_row "Task execution overview:" "${base_urls[0]}/s/${build_scan_ids[1]}/performance/execution"
  summary_row "Executed tasks timeline:" "${base_urls[0]}/s/${build_scan_ids[1]}/timeline?outcome=success,failed&sort=longest"
  summary_row "Uptodate tasks:" "${base_urls[0]}/s/${build_scan_ids[1]}/timeline?outcome=up-to-date&sort=longest"
  summary_row "Task inputs comparison:" "${base_urls[0]}/c/${build_scan_ids[0]}/${build_scan_ids[1]}/task-inputs"
}

print_introduction() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_introduction_title)

In this experiment, you will validate how well a given project leverages
Gradle’s incremental build functionality. A build is considered fully
incremental if it can be invoked twice in a row with build caching disabled and,
during the second invocation, all tasks avoid performing any work because:

  * The tasks' inputs have not changed since their last invocation and
  * The tasks' outputs are still present

The experiment will reveal tasks with volatile inputs, for example tasks that
contain a timestamp in one of their inputs. It will also reveal tasks that produce
non-deterministic outputs consumed by tasks downstream that participate in
incremental building, for example tasks generating code with non-deterministic
method ordering or tasks producing artifacts that include timestamps.

The experiment will assist you to first identify those tasks that do not
participate in Gradle’s incremental build functionality, to then make an
informed decision which of those tasks are worth improving to make your build
faster, to then investigate why they do not participate in incremental building,
and to finally fix them once you understand the root cause.

The experiment can be run on any developer’s machine. It logically consists of
the following steps:

  1. Disable build caching completely
  2. Run the build with a typical task invocation including the 'clean' task
  3. Run the build with the same task invocation but without the 'clean' task
  4. Determine which tasks are still executed in the second run and why
  5. Assess which of the executed tasks are worth improving
  6. Fix identified tasks

The script you have invoked automates the execution of step 1, step 2, and step 3
without modifying the project. Build scans support your investigation in step 4
and step 5.

After improving the build to make it more incremental, you can push your changes
and run the experiment again. This creates a cycle of run → measure → improve → run.

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
given Gradle tasks. The build will be invoked with the 'clean' task included
and build caching disabled.

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
with the same Gradle tasks. This time, the build will be invoked without the
'clean' task included and build caching still disabled.

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

Now that the second build has finished successfully, you are ready to measure
in Develocity how well your build leverages Gradle’s incremental build
functionality for the invoked set of Gradle tasks.

Some of the build scan data will be fetched from the build scans produced by
the two builds to assist you in your investigation.

${USER_ACTION_COLOR}Press <Enter> to measure the build results.${RESTORE}
EOF
  print_interactive_text "${text}"
  wait_for_enter
}

explain_and_print_summary() {
  local text
  IFS='' read -r -d '' text <<EOF
The ‘Summary’ section below captures the configuration of the experiment and
the two build scans that were published as part of running the experiment. The
build scan of the second build is particularly interesting since this is where
you can inspect what tasks were not leveraging Gradle’s incremental build
functionality.

$(explain_performance_characteristics)

The ‘Investigation Quick Links’ section below allows quick navigation to the
most relevant views in build scans to investigate what tasks were up-to-date
and what tasks executed in the second build, which of those tasks had the
biggest impact on build performance, and what caused those tasks to not be
up-to-date.

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
The ‘Performance Characteristics’ section below reveals the realized build time
savings as a result of leveraging Gradle’s incremental build functionality.
EOF
  echo -n "${text}"
}

process_args "$@"
main
