#!/usr/bin/env bash
#
# Runs Experiment 05 - Validate Gradle Remote Build Caching - CI and Local
#
# Invoke this script with --help to get a description of the command line arguments
#
readonly EXP_NAME="Validate remote build caching - CI and local"
readonly EXP_DESCRIPTION="Validating that a Gradle build is optimized for remote build caching when invoked on CI agent and local machine"
readonly EXP_NO="05"
readonly EXP_SCAN_TAG=exp5-gradle
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
# shellcheck source=lib/scripts/05-cli-parser.sh
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

ci_build_scan_url=''
remote_build_cache_type=''
remote_build_cache_url=''
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
  fetch_build_params_from_build_scan
  validate_build_config

  print_bl
  make_experiment_dir
  git_checkout_project "build_${project_name}"

  print_bl
  execute_build

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
  explain_prerequisites_gradle_remote_build_cache_config "II."

  print_bl
  explain_prerequisites_empty_remote_build_cache "III."

  print_bl
  explain_prerequisites_api_access "IV."

  print_bl
  explain_ci_build
  print_bl
  collect_ci_build_scan

  print_bl
  explain_collect_mapping_file
  print_bl
  collect_mapping_file

  print_bl
  fetch_build_params_from_build_scan

  print_bl
  explain_collect_git_details
  print_bl
  collect_git_details

  print_bl
  explain_collect_gradle_details
  print_bl
  collect_gradle_details

  print_bl
  explain_collect_remote_build_cache
  print_bl
  collect_remote_build_cache
  explain_command_to_repeat_experiment_after_collecting_parameters

  print_bl
  explain_clone_project
  print_bl
  make_experiment_dir
  git_checkout_project "build_${project_name}"

  print_bl
  explain_build
  print_bl
  execute_build

  print_bl
  explain_measure_build_results
  print_bl
  process_build_scan_data
  print_bl
  explain_and_print_summary
}

map_additional_script_args() {
  ci_build_scan_url="${_arg_first_build_ci}"
  remote_build_cache_type="${_arg_remote_build_cache_type}"
  remote_build_cache_url="${_arg_remote_build_cache_url}"
  mapping_file="${_arg_mapping_file}"
}

# Overrides config.sh#validate_required_args
validate_required_args() {
  if [ "${interactive_mode}" == "off" ]; then
    if [ -z "${ci_build_scan_url}" ]; then
      _PRINT_HELP=yes die "ERROR: Missing required argument: --first-build-ci" "${INVALID_INPUT}"
    fi
  fi

  if [[ "${enable_develocity}" == "on" && -z "${develocity_server}" ]]; then
    _PRINT_HELP=yes die "ERROR: Missing required argument when enabling Develocity on a project not already connected: --develocity-server" "${INVALID_INPUT}"
  fi

  if [[ -n "${remote_build_cache_type}" && "${remote_build_cache_type}" != 'http' && "${remote_build_cache_type}" != 'gradle-enterprise' && "${remote_build_cache_type}" != 'develocity' ]]; then
    _PRINT_HELP=yes die "ERROR: Invalid value for argument --remote-build-cache-type. Values are 'develocity', 'gradle-enterprise', or 'http'." "${INVALID_INPUT}"
  fi
}

fetch_build_params_from_build_scan() {
  build_scan_urls+=( "${ci_build_scan_url}" )
  fetch_single_build_scan "${ci_build_scan_url}"
  read_build_params_from_build_scan_data
}

read_build_params_from_build_scan_data() {
  if [[ "${remote_build_cache_types[0]}" == "disabled" ]]; then
    die "ERROR: Remote build cache was disabled for the first build. Enable the remote build cache in the build and restart the experiment."
  fi
  if [ -z "${git_repo}" ]; then
    git_repo="${git_repos[0]}"
    project_name="$(basename -s .git "${git_repo}")"
  fi
  if [ -z "${git_branch}" ]; then
    git_branch="${git_branches[0]}"
  fi
  if [ -z "${git_commit_id}" ]; then
    git_commit_id="${git_commit_ids[0]}"
  fi
  if [[ -z "${remote_build_cache_type}" && "${remote_build_cache_types[0]}" != "unknown" ]]; then
    remote_build_cache_type="${remote_build_cache_types[0]}"
  fi
  if [ -z "${remote_build_cache_url}" ]; then
    remote_build_cache_url="${remote_build_cache_urls[0]}"
  fi
  if [ -z "${tasks}" ]; then
    tasks="${requested_tasks[0]}"
    remove_clean_from_tasks
  fi
}

validate_build_config() {
  if [ -z "${git_repo}" ]; then
    _PRINT_HELP=yes die "ERROR: Git repository URL was not found in the build scan. Specify missing argument: --git-repo" "${INVALID_INPUT}"
  fi

  if [ -z "${tasks}" ]; then
    _PRINT_HELP=yes die "ERROR: Gradle tasks were not found in the build scan. Specify missing argument: --tasks" "${INVALID_INPUT}"
  fi

  if [ -z "${git_commit_id}" ]; then
    _PRINT_HELP=yes die "ERROR: Git commit id was not found in the build scan. Specify missing argument: --git-commit-id" "${INVALID_INPUT}"
  fi
}

execute_build() {
  local args
  args=(--build-cache --init-script "${INIT_SCRIPTS_DIR}/configure-remote-build-caching.gradle")
  if [ -n "${remote_build_cache_type}" ]; then
    args+=("-Ddevelocity.build-validation.remoteBuildCacheType=${remote_build_cache_type}")
  fi
  if [ -n "${remote_build_cache_url}" ]; then
    args+=("-Ddevelocity.build-validation.remoteBuildCacheUrl=${remote_build_cache_url}")
  fi

  # shellcheck disable=SC2206  # we want tasks to expand with word splitting in this case
  args+=(clean ${tasks})

  info "Running build:"
  info "./gradlew --build-cache -Dscan.tag.${EXP_SCAN_TAG} -Dscan.value.runId=${RUN_ID} -Dpts.enabled=false clean ${tasks}$(print_extra_args)"

  invoke_gradle 1 "${args[@]}"
}

process_build_scan_data() {
  process_build_scan_data_online "$LOGGING_BRIEF" "$RUN_ID_NONE"
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
a CI agent and then on a local machine. A build is considered fully cacheable
if it can be invoked twice in a row with build caching enabled and, during the
second invocation, all cacheable tasks avoid performing any work because:

  * The cacheable tasks' inputs have not changed since their last invocation and
  * The cacheable tasks' outputs are present in the remote build cache and
  * No cacheable tasks were excluded from build caching to ensure correctness

The experiment will reveal tasks with volatile inputs, for example tasks that
contain a timestamp in one of their inputs. It will also reveal tasks that
produce non-deterministic outputs consumed by cacheable tasks downstream, for
example tasks generating code with non-deterministic method ordering or tasks
producing artifacts that include timestamps. It will also reveal tasks that
contain an absolute file path in one of their inputs.

The experiment will assist you to first identify those tasks whose outputs are
not taken from the remote build cache due to changed inputs or to ensure
correctness of the build, to then make an informed decision which of those tasks
are worth improving to make your build faster, to then investigate why they are
not taken from the remote build cache, and to finally fix them once you
understand the root cause.

The first part of the experiment runs in your CI environment and the second
part of the experiment runs on any developer's machine. It logically consists of
the following steps:

  1. Enable only remote build caching and use an empty remote build cache
  2. On a given CI agent, run a typical CI configuration from a fresh checkout
  3. On a developer machine, run the build with the same task invocation including the ‘clean’ task with the same commit id
  4. Determine which cacheable tasks are still executed in the second run and why
  5. Assess which of the executed, cacheable tasks are worth improving
  6. Fix identified tasks

The script you have invoked does not automate the execution of step 1 and step 2.
You will need to complete these steps manually. The script automates the
execution of step 3 without modifying the project. Build scans support your
investigation in step 4 and step 5.

After improving the build to make it better leverage the remote build cache,
you can push your changes and run the experiment again. This creates a cycle
of run → measure → improve → run.

${USER_ACTION_COLOR}Press <Enter> to get started with the experiment.${RESTORE}
EOF

  print_interactive_text "${text}"
  wait_for_enter
}

explain_ci_build() {
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

collect_ci_build_scan() {
  prompt_for_setting "What is the build scan URL of the build run on CI?" "${_arg_first_build_ci}" "" ci_build_scan_url
}

explain_collect_mapping_file() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_separator)
${HEADER_COLOR}Fetch build scan data${RESTORE}

Now that the build on CI has finished successfully, some of the build scan
data will be fetched from the provided build scan to assist you in your
investigation.

The build scan data will be fetched via the Develocity API, as explained earlier
in the preparations section of this experiment.

Some of the fetched build scan data is expected to be present as custom values.
By default, this experiment assumes that these custom values have been created
by the Common Custom User Data Gradle plugin. If you are not using that plugin
but your build still captures the same data under different custom value names,
you can provide a mapping file so that the required data can be extracted from
your build scans. An example mapping file named 'mapping.example' can be found
at the same location as the script.
EOF
  print_interactive_text "${text}"
}

# This overrides explain_collect_git_details found in lib/interactive-mode.sh
explain_collect_git_details() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_separator)
${HEADER_COLOR}Configure local build${RESTORE}

Now that the first build has finished successfully on CI and the build scan
data has been fetched or at least attempted to be fetched, the second build
can be run locally with the same commit id, the same Gradle tasks, and the
same remote build cache as was used by the first build.

The local build will run after a fresh checkout of the given project stored in
Git. The fresh checkout ensures reproducibility of the experiment across machines
and users since no local changes and commits will be accidentally included in the
validation process.

Make sure the local build uses the proper branch and commit id.
EOF
  print_interactive_text "${text}"
}

# This overrides explain_collect_gradle_details found in lib/interactive-mode.sh
explain_collect_gradle_details() {
  local text
  IFS='' read -r -d '' text <<EOF
Once the project is checked out from Git, the experiment will invoke the
project’s contained Gradle build with a given set of tasks and an optional set
of arguments. The Gradle tasks to invoke should be the same, or very similar to
the tasks invoked by the previous CI build.

The build will be invoked from the project’s root directory or from a given
sub-directory.
EOF
  print_interactive_text "${text}"
}

explain_collect_remote_build_cache() {
  local text
  IFS='' read -r -d '' text <<EOF
The local build will connect to the given remote build cache. The remote build
cache to use should be the same as the one used by the previous CI build.
EOF
  print_interactive_text "${text}"
}

collect_remote_build_cache() {
  collect_remote_build_cache_type
  collect_remote_build_cache_url
}

collect_remote_build_cache_type() {
  local default_remote_cache_type="<project default>"
  prompt_for_setting "What is the remote build cache connector type to use? [develocity, gradle-enterprise, http, or <BLANK>]" "${remote_build_cache_type}" "${default_remote_cache_type}" remote_build_cache_type

  if [[ -n "${remote_build_cache_type}" && "${remote_build_cache_type}" != 'http' && "${remote_build_cache_type}" != 'gradle-enterprise' && "${remote_build_cache_type}" != 'develocity' ]]; then
    print_bl
    die "ERROR: Invalid value for remote build cache connector type. Values are 'develocity', 'gradle-enterprise', 'http', or <BLANK> for project default." "${INVALID_INPUT}"
  fi

  if [[ "${remote_build_cache_type}" == "${default_remote_cache_type}" ]]; then
    remote_build_cache_type=''
  fi
}

collect_remote_build_cache_url() {
  local default_remote_cache_url="<project default>"
  prompt_for_setting "What is the remote build cache url to use?" "${remote_build_cache_url}" "${default_remote_cache_url}" remote_build_cache_url

  if [[ "${remote_build_cache_url}" == "${default_remote_cache_url}" ]]; then
    remote_build_cache_url=''
  fi
}

# This overrides explain_clone_project found in lib/interactive-mode.sh
explain_clone_project() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_separator)
${HEADER_COLOR}Check out project from Git for local build${RESTORE}

All configuration to run the local build has been collected. The Git repository
that contains the project to validate will be checked out.

${USER_ACTION_COLOR}Press <Enter> to check out the project from Git.${RESTORE}
EOF
  print_interactive_text "${text}"
  wait_for_enter
}

explain_build() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_separator)
${HEADER_COLOR}Run local build${RESTORE}

Now that the project has been checked out, the local build can be run with the
given Gradle tasks.

${USER_ACTION_COLOR}Press <Enter> to run the local build of the experiment.${RESTORE}
EOF
  print_interactive_text "${text}"
  wait_for_enter
}

explain_measure_build_results() {
  local text
  IFS='' read -r -d '' text <<EOF
$(print_separator)
${HEADER_COLOR}Measure build results${RESTORE}

At this point, you are ready to measure in Develocity how well your build
leverages Gradle’s remote build cache for the set of Gradle tasks invoked from a
CI agent and then on a local machine.

Some of the build scan data will be fetched from the build scans produced by the
two builds to assist you in your investigation.

${USER_ACTION_COLOR}Press <Enter> to measure the build results.${RESTORE}
EOF
  print_interactive_text "${text}"
  wait_for_enter
}

#Overrides config.sh#generate_command_to_repeat_experiment
generate_command_to_repeat_experiment() {
  local cmd
  cmd=("./${SCRIPT_NAME}")

  if [ -n "${git_repo}" ] && [[ "${git_repo}" != "${git_repos[0]}" ]]; then
    cmd+=("-r" "${git_repo}")
  fi

  if [ -n "${git_branch}" ] && [[ "${git_branch}" != "${git_branches[0]}" ]]; then
    cmd+=("-b" "${git_branch}")
  fi

  if [ -n "${git_commit_id}" ] && [[ "${git_commit_id}" != "${git_commit_ids[0]}" ]]; then
    cmd+=("-c" "${git_commit_id}")
  fi

  if [ -n "${project_dir}" ]; then
    cmd+=("-p" "${project_dir}")
  fi

  if [ -n "${tasks}" ] && [[ "${tasks}" != "${requested_tasks[0]}" ]]; then
    cmd+=("-t" "${tasks}")
  fi

  if [ -n "${extra_args}" ]; then
    cmd+=("-a" "${extra_args}")
  fi

  if [ -n "${ci_build_scan_url}" ]; then
    cmd+=("-1" "${ci_build_scan_url}")
  fi

  if [ -n "${mapping_file}" ]; then
    cmd+=("-m" "${mapping_file}")
  fi

  if [ -n "${remote_build_cache_type}" ]; then
    cmd+=("-y" "${remote_build_cache_type}")
  fi

  if [ -n "${remote_build_cache_url}" ]; then
    cmd+=("-u" "${remote_build_cache_url}")
  fi

  if [ -n "${develocity_server}" ]; then
    cmd+=("-s" "${develocity_server}")
  fi

  if [[ "${enable_develocity}" == "on" ]]; then
    cmd+=("-e")
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
