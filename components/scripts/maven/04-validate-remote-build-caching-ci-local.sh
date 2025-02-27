#!/usr/bin/env bash
#
# Runs Experiment 05 - Validate Gradle Remote Build Caching - CI and Local
#
# Invoke this script with --help to get a description of the command line arguments
#
readonly EXP_NAME="Validate remote build caching - CI and local"
readonly EXP_DESCRIPTION="Validating that a Maven build is optimized for remote build caching when invoked on CI agent and local machine"
readonly EXP_NO="04"
readonly EXP_SCAN_TAG=exp4-maven
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
# shellcheck source=lib/scripts/04-cli-parser.sh
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
develocity_server=''
interactive_mode=''

ci_build_scan_url=''
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
  process_build_scan_data_online

  print_bl
  print_summary
}

wizard_execute() {
  print_introduction

  print_bl
  explain_prerequisites_ccud_maven_extension "I."

  print_bl
  explain_prerequisites_maven_remote_build_cache_config "II."

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
  explain_collect_maven_details
  print_bl
  collect_maven_details

  print_bl
  explain_remote_build_cache_url
  print_bl
  collect_remote_build_cache_url
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
  process_build_scan_data_online
  print_bl
  explain_and_print_summary
}

map_additional_script_args() {
  ci_build_scan_url="${_arg_first_build_ci}"
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
    _PRINT_HELP=yes die "ERROR: Maven goals were not found in the build scan. Specify missing argument: --goals" "${INVALID_INPUT}"
  fi

  if [ -z "${git_commit_id}" ]; then
    _PRINT_HELP=yes die "ERROR: Git commit id was not found in the build scan. Specify missing argument: --git-commit-id" "${INVALID_INPUT}"
  fi
}

execute_build() {
  local args
  args=(
    -Dgradle.cache.local.enabled=false
    -Dgradle.cache.remote.enabled=true
    -Ddevelocity.cache.local.enabled=false
    -Ddevelocity.cache.remote.enabled=true
  )
  if [ -n "${remote_build_cache_url}" ]; then
    args+=(
      -Dgradle.cache.remote.url="${remote_build_cache_url}"
      -Ddevelocity.cache.remote.url="${remote_build_cache_url}"
    )
  fi

  # shellcheck disable=SC2206  # we want tasks to expand with word splitting in this case
  args+=(clean ${tasks})

  info "Running build:"
  info "./mvnw -Dscan -Dscan.tag.${EXP_SCAN_TAG} -Dscan.value.runId=${RUN_ID} -Dpts.enabled=false clean ${tasks}$(print_extra_args)"

  # shellcheck disable=SC2086  # we want tasks to expand with word splitting in this case
  invoke_maven 1 "${args[@]}"
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
Develocity's remote build caching functionality when running the build from a CI
agent and then on a local machine. A build is considered fully cacheable if it
can be invoked twice in a row with build caching enabled and, during the second
invocation, all cacheable goals avoid performing any work because:

  * The cacheable goals' inputs have not changed since their last invocation and
  * The cacheable goals' outputs are present in the remote build cache and
  * No cacheable goals were excluded from build caching to ensure correctness

The experiment will reveal goals with volatile inputs, for example goals that
contain a timestamp in one of their inputs. It will also reveal goals that
produce non-deterministic outputs consumed by cacheable goals downstream, for
example goals generating code with non-deterministic method ordering or goals
producing artifacts that include timestamps. It will also reveal goals that
contain an absolute file path in one of their inputs.

The experiment will assist you to first identify those goals whose outputs are
not taken from the remote build cache due to changed inputs or to ensure
correctness of the build, to then make an informed decision which of those goals
are worth improving to make your build faster, to then investigate why they are
not taken from the remote build cache, and to finally fix them once you
understand the root cause.

The first part of the experiment runs in your CI environment and the second
part of the experiment runs on any developer's machine. It logically consists of
the following steps:

  1. Enable only remote build caching and use an empty remote build cache
  2. On a given CI agent, run a typical CI configuration from a fresh checkout
  3. On a developer machine, run the build with the same goal invocation including the ‘clean’ goal with the same commit id
  4. Determine which cacheable goals are still executed in the second run and why
  5. Assess which of the executed, cacheable goals are worth improving
  6. Fix identified goals

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

The build scan data will be fetched via the Develocity API. It is not strictly
necessary that you have permission to call the API while doing this experiment,
but the summary provided at the end of the experiment will be more comprehensive
if the build scan data is accessible. You can check your granted permissions by
navigating in the browser to the 'My Settings' section from the user menu of
your Develocity UI. Your Develocity access key must be specified in the
~/.m2/.develocity/keys.properties file.

https://docs.gradle.com/develocity/maven-extension/current/#via_file

Some of the fetched build scan data is expected to be present as custom values.
By default, this experiment assumes that these custom values have been created
by the Common Custom User Data Maven extension. If you are not using that
extension but your build still captures the same data under different custom
value names, you can provide a mapping file so that the required data can be
extracted from your build scans. An example mapping file named 'mapping.example'
can be found at the same location as the script.
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
can be run locally with the same commit id, the same Gradle goals, and the
same remote build cache as was used by the first build.

The local build will run after a fresh checkout of the given project stored in
Git. The fresh checkout ensures reproducibility of the experiment across machines
and users since no local changes and commits will be accidentally included in the
validation process.

Make sure the local build uses the proper branch and commit id.
EOF
  print_interactive_text "${text}"
}

# This overrides explain_collect_maven_details found in lib/interactive-mode.sh
explain_collect_maven_details() {
  local text
  IFS='' read -r -d '' text <<EOF
Once the project is checked out from Git, the experiment will invoke the
project’s contained Maven build with a given set of goals and an optional set
of arguments. The Maven goals to invoke should be the same, or very similar to
the goals invoked by the previous CI build.

The build will be invoked from the project’s root directory or from a given
sub-directory.
EOF
  print_interactive_text "${text}"
}

explain_remote_build_cache_url() {
  local text
  IFS='' read -r -d '' text <<EOF
The local build will connect to the given remote build cache. The remote build
cache to use should be the same as the one used by the previous CI build.
EOF
  print_interactive_text "${text}"
}

collect_remote_build_cache_url() {
  local default_remote_cache="<project default>"
  prompt_for_setting "What is the remote build cache url to use?" "${remote_build_cache_url}" "${default_remote_cache}" remote_build_cache_url

  if [[ "${remote_build_cache_url}" == "${default_remote_cache}" ]]; then
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
given Maven goals.

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
leverages Develocity's remote build cache for the set of Gradle goals invoked
from a CI agent and then on a local machine.

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
    cmd+=("-g" "${tasks}")
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
inspect what goals were not leveraging the remote build cache.

The ‘Performance Characteristics’ section below reveals the realized and
potential savings from build caching. All cacheable goals' outputs need to be
taken from the build cache in the second build for the build to be fully
cacheable.

The ‘Investigation Quick Links’ section below allows quick navigation to the
most relevant views in build scans to investigate what goals were avoided due to
remote build caching and what goals executed in the second build, which of those
goals had the biggest impact on build performance, and what caused those goals
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
