#!/usr/bin/env bash

print_script_usage() {
  echo "USAGE: ${SCRIPT_NAME} [option...]"
  echo
}

print_option_usage() {
  local key="$1"

  case "$key" in
    -i)
       _print_option_usage "-i, --interactive" "Enables interactive mode."
       ;;
    -r)
       _print_option_usage "-r, --git-repo" "Specifies the URL for the Git repository to validate."
       ;;
    -b)
       _print_option_usage "-b, --git-branch" "Specifies the branch for the Git repository to validate."
       ;;
    -c)
       _print_option_usage "-c, --git-commit-id" "Specifies the Git commit id for the Git repository to validate."
       ;;
    -o)
       _print_option_usage "-o, --git-options" "Specifies additional arguments to apply when cloning the Git repository."
       ;;
    -p)
       _print_option_usage "-p, --project-dir" "Specifies the build invocation directory within the Git repository."
       ;;
    -t)
       _print_option_usage "-t, --tasks" "Specifies the Gradle tasks to invoke."
       ;;
    -g)
       _print_option_usage "-g, --goals" "Specifies the Maven goals to invoke."
       ;;
    -a)
       _print_option_usage "-a, --args" "Specifies additional arguments to pass to ${BUILD_TOOL}."
       ;;
    -m)
       _print_option_usage "-m, --mapping-file" "Specifies the mapping file for the custom value names used in the build scans."
       ;;
    -s)
       _print_option_usage "-s, --gradle-enterprise-server" "Specifies the URL for the Gradle Enterprise server to connect to."
       ;;
    -e)
       _print_option_usage "-e, --enable-gradle-enterprise" "Enables Gradle Enterprise on a project not already connected."
       ;;
    -x)
       _print_option_usage "-x, --disable-build-scan-publishing" "Disables the publication of build scans on the invoked builds."
       ;;
    -f)
       _print_option_usage "-f, --fail-if-not-fully-cacheable" "Terminates with exit code ${BUILD_NOT_FULLY_CACHEABLE} if the build is not fully cacheable."
       ;;
    -v)
       _print_option_usage "-v, --version" "Prints version info."
       ;;
    -h)
       _print_option_usage "-h, --help" "Shows this help message."
       ;;
    *)
       _print_option_usage "$1" "$2"
  esac
}

_print_option_usage() {
  local flags="$1"
  local description="$2"

  local fmt="%-36s%s\n"
  #shellcheck disable=SC2059
  printf "$fmt" "$flags" "$description"
}

print_version() {
  echo "${SCRIPT_VERSION}"
}

