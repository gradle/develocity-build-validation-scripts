#!/usr/bin/env bash
#
# Runs Experiment 04 - Validate remote build caching - different CI agents
#
# Invoke this script with --help to get a description of the command line arguments
#
readonly EXP_NAME="Validate remote build caching - different CI agents"
readonly EXP_DESCRIPTION="Validating that a Gradle build is optimized for remote build caching when invoked from different CI agents"
readonly EXP_NO="04"
readonly EXP_SCAN_TAG=exp4-gradle
readonly BUILD_TOOL="Gradle"
readonly SCRIPT_VERSION="<HEAD>"
readonly SUMMARY_VERSION="<SUMMARY_VERSION>"
readonly SHOW_RUN_ID=false

# Needed to bootstrap the script
SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_NAME
# shellcheck disable=SC2164  # it is highly unlikely cd will fail here because we're cding to the location of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; cd -P "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo .)")"; pwd)"
readonly SCRIPT_DIR
readonly LIB_DIR="${SCRIPT_DIR}/lib/scripts"

# Include and parse the command line arguments
# shellcheck source=lib/scripts/04-cli-parser.sh
source "${LIB_DIR}/${EXP_NO}-cli-parser.sh" || { echo -e "\033[00;31m\033[1mERROR: Couldn't find '${LIB_DIR}/${EXP_NO}-cli-parser.sh'\033[0m"; exit 100; }
# shellcheck source=lib/scripts/libs.sh
# shellcheck disable=SC2154 # the libs include scripts that reference CLI arguments that this script does not create
source "${LIB_DIR}/libs.sh" || { echo -e "\033[00;31m\033[1mERROR: Couldn't find '${LIB_DIR}/libs.sh'\033[0m"; exit 100; }

# These will be set by the config functions (see lib/config.sh)
git_repo=''
project_name=''
git_branch=''
git_options='<not available>'
project_dir='<not available>'
extra_args='<not available>'
tasks=''
enable_develocity=''
develocity_server=''
interactive_mode=''
mapping_file=''

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
  process_build_scan_data
  make_experiment_dir

  print_bl
  print_summary
}

wizard_execute() {
  print_introduction

  print_bl
  explain_prerequisites_ccud_gradle_plugin "I."

  print_bl
  explain_prerequisites_gradle_remote_build_cache_config "II."

  print_bl
  explain_prerequisites_empty_remote_build_cache "III."

  print_bl
  explain_prerequisites_api_access "IV."

  print_bl
  explain_first_build
  print_bl
  collect_first_build_scan

  print_bl
  explain_second_build
  print_bl
  collect_second_build_scan

  print_bl
  explain_collect_mapping_file
  print_bl
  collect_mapping_file
  explain_command_to_repeat_experiment_after_collecting_parameters

  print_bl
  process_build_scan_data
  make_experiment_dir

  print_bl
  explain_measure_build_results
  print_bl
  explain_and_print_summary
}

# Overrides config.sh#validate_required_args
validate_required_args() {
  if [ "${interactive_mode}" == "off" ]; then
    if [ -z "${_arg_first_build_ci}" ]; then
      _PRINT_HELP=yes die "ERROR: Missing required argument: --first-build-ci" "${INVALID_INPUT}"
    fi

    if [ -z "${_arg_second_build_ci}" ]; then
      _PRINT_HELP=yes die "ERROR: Missing required argument: --second-build-ci" "${INVALID_INPUT}"
    fi

    build_scan_urls+=("${_arg_first_build_ci}")
    build_scan_urls+=("${_arg_second_build_ci}")
  fi
}

process_build_scan_data() {
  process_build_scan_data_online "$LOGGING_VERBOSE" "$(query_none)"
}

# Overrides summary.sh#print_experiment_specific_summary_info
print_experiment_specific_summary_info() {
  summary_row "Custom value mapping file:" "${mapping_file:-<none>}"
}

print_introduction() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_introduction_title)

In this experiment, you will validate how well a given project leverages
Gradle's remote build caching functionality when running the build from
two different CI agents. A build is considered fully cacheable if it can be
invoked twice in a row with build caching enabled and, during the second
invocation, all cacheable tasks avoid performing any work because:

  * The cacheable tasks' inputs have not changed since their last invocation and
  * The cacheable tasks' outputs are present in the remote build cache and
  * No cacheable tasks were excluded from build caching to ensure correctness

The experiment will reveal tasks with volatile inputs, for example tasks that
contain a timestamp in one of their inputs. It will also reveal tasks that
produce non-deterministic outputs consumed by cacheable tasks downstream, for
example tasks generating code with non-deterministic method ordering or tasks
producing artifacts that include timestamps.

The experiment will assist you to first identify those tasks whose outputs are
not taken from the remote build cache due to changed inputs or to ensure
correctness of the build, to then make an informed decision which of those tasks
are worth improving to make your build faster, to then investigate why they are
not taken from the remote build cache, and to finally fix them once you
understand the root cause.

The experiment needs to be run in your CI environment. It logically consists of
the following steps:

  1. Enable only remote build caching and use an empty remote build cache
  2. On a given CI agent, run a typical CI configuration from a fresh checkout
  3. On another CI agent, run the same CI configuration with the same commit id from a fresh checkout
  4. Determine which cacheable tasks are still executed in the second run and why
  5. Assess which of the executed, cacheable tasks are worth improving
  6. Fix identified tasks

The script you have invoked does not automate the execution of step 1, step 2,
and step 3. You will need to complete these steps manually. Build scans support
your investigation in step 4 and step 5.

After improving the build to make it better leverage the remote build cache,
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
${HEADER_COLOR}Run first build on CI agent${RESTORE}

You can now trigger the first build on one of your CI agents. The invoked CI
configuration should be a configuration that is typically triggered when
building the project as part of your pipeline during daily development.

Make sure the CI configuration uses the proper branch and performs a fresh
checkout to avoid any build artifacts lingering around from a previous build
that could influence the experiment.

Also, make sure the CI configuration builds the project with Predictive Test
Selection (PTS) disabled, as test results will not be stored in the build cache
when only a subset of tests are selected for execution. PTS can be globally
disabled using the '-Dpts.enabled=false' system property.

Once the build completes, make a note of the commit id that was used, and enter
the URL of the build scan produced by the build.
EOF
  print_interactive_text "${text}"
}

collect_first_build_scan() {
  prompt_for_setting "What is the build scan URL of the first build?" "${_arg_first_build_ci}" "" build_scan_url
  build_scan_urls+=("${build_scan_url}")
}

explain_second_build() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_separator)
${HEADER_COLOR}Run second build on another CI agent${RESTORE}

Now that the first build has finished successfully, the second build can be
triggered on another CI agent for the same CI configuration and with the same
commit id as was used by the first build.

Make sure the CI configuration uses the proper branch and commit id and performs
a fresh checkout to avoid any build artifacts lingering around from a previous
build that could influence the experiment.

Once the build completes, enter the URL of the build scan produced by the build.
EOF
  print_interactive_text "${text}"
}

collect_second_build_scan() {
  prompt_for_setting "What is the build scan URL of the second build?" "${_arg_second_build_ci}" "" build_scan_url
  build_scan_urls+=("${build_scan_url}")
}

explain_collect_mapping_file() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_separator)
${HEADER_COLOR}Fetch build scan data${RESTORE}

Now that the second build has finished successfully, some of the build scan
data will be fetched from the two provided build scans to assist you in your
investigation.

The build scan data will be fetched via the Develocity API, as explained earlier
in the preparations section of this experiment.

Some of the fetched build scan data is expected to be present as custom values.
By default, this experiment assumes that these custom values have been created
by the Common Custom User Data Gradle plugin. If you are not using that plugin
but your build still captures the same data under different custom value names,
you can provide a mapping file so that the required data can be extracted from
your build scans. Details on how to provide a mapping file are available from
the documentation of the build validation scripts.
EOF
  print_interactive_text "${text}"
}

explain_measure_build_results() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_separator)
${HEADER_COLOR}Measure build results${RESTORE}

At this point, you are ready to measure in Develocity how well your build
leverages Gradle’s remote build cache for the set of Gradle tasks invoked from
two different CI agents.

${USER_ACTION_COLOR}Press <Enter> to measure the build results.${RESTORE}
EOF
  print_interactive_text "${text}"
  wait_for_enter
}

#Overrides config.sh#generate_command_to_repeat_experiment
generate_command_to_repeat_experiment() {
  local cmd
  cmd=("./${SCRIPT_NAME}")
  cmd+=("-1" "${build_scan_urls[0]}")
  cmd+=("-2" "${build_scan_urls[1]}")

  if [ -n "${mapping_file}" ]; then
    cmd+=("-m" "${mapping_file}")
  fi

  if [[ "${fail_if_not_fully_cacheable}" == "on" ]]; then
    cmd+=("-f")
  fi

  if [[ "${debug_mode}" == "on" ]]; then
    cmd+=("--debug")
  fi

  printf '%q ' "${cmd[@]}"
}

explain_and_print_summary() {
  local text
  IFS='' read -r -d '' text <<EOF
The ‘Summary‘ section below captures the configuration of the experiment and the
two build scans that were published as part of running the experiment. The build
scan of the second build is particularly interesting since this is where you can
inspect what tasks were not leveraging Gradle’s remote build cache.

The ‘Performance Characteristics’ section below reveals the realized and
potential savings from build caching. All cacheable tasks' outputs need to be
taken from the build cache in the second build for the build to be fully
cacheable.

The ‘Investigation Quick Links’ section below allows quick navigation to the
most relevant views in build scans to investigate what tasks were avoided due to
remote build caching and what tasks executed in the second build, which of those
tasks had the biggest impact on build performance, and what caused those tasks
to not be taken from the remote build cache.

$(explain_command_to_repeat_experiment)

$(print_summary)

$(print_command_to_repeat_experiment)

$(explain_when_to_rerun_experiment)
EOF
  print_interactive_text "${text}"
}

process_args "$@"
main
