#!/usr/bin/env bash
# shellcheck disable=SC2034  # It is common for variables in this auto-generated file to go unused
# Created by argbash-init v2.10.0
# ARG_OPTIONAL_SINGLE([first-build-ci],[1],[])
# ARG_OPTIONAL_SINGLE([mapping-file],[m],[])
# ARG_OPTIONAL_SINGLE([remote-build-cache-type],[y],[])
# ARG_OPTIONAL_SINGLE([remote-build-cache-url],[u],[])
# ARG_OPTIONAL_BOOLEAN([fail-if-not-fully-cacheable],[f],[])
# ARG_HELP([This function is overridden later on.])
# ARG_VERSION([print_version],[v],[version],[])
# ARGBASH_WRAP([common])
# ARGBASH_SET_INDENT([  ])
# ARGBASH_PREPARE()
# needed because of Argbash --> m4_ignore([
### START OF CODE GENERATED BY Argbash v2.10.0 one line above ###
# Argbash is a bash code generator used to get arguments parsing right.
# Argbash is FREE SOFTWARE, see https://argbash.io for more info
### END OF CODE GENERATED BY Argbash (sortof) ### ])
# [ <-- needed because of Argbash
function print_help() {
  echo "Assists in validating that a Gradle build is optimized for remote build caching when invoked on CI agent and local machine."
  print_bl
  print_script_usage
  print_option_usage -i
  print_option_usage "-1, --first-build-ci" "Specifies the URL for the build scan of the first build run by a CI agent."
  print_option_usage -m
  print_option_usage -r
  print_option_usage -b
  print_option_usage -c
  print_option_usage -o
  print_option_usage -p
  print_option_usage -t
  print_option_usage -a
  print_option_usage "-y, --remote-build-cache-type" "Specifies the remote build cache connector type to use in the second build run locally. Values are 'develocity', 'gradle-enterprise', or 'http'."
  print_option_usage "-u, --remote-build-cache-url" "Specifies the URL for the remote build cache to access in the second build run locally."
  print_option_usage -s
  print_option_usage -e
  print_option_usage -f
  print_option_usage -v
  print_option_usage -h
}
# ] <-- needed because of Argbash
