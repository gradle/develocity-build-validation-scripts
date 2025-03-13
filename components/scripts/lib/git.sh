#!/usr/bin/env bash

git_checkout_project() {
   local target_subdir="$1"
   if [ -n "${git_commit_id}" ]; then
     git_checkout_commit "${target_subdir}"
   else
     git_clone_project "${target_subdir}"
   fi

   if [ -x "${SCRIPT_DIR}/hooks/post-checkout.sh" ]; then
     "${SCRIPT_DIR}/hooks/post-checkout.sh"
   fi
}

git_clone_project() {
   local target_subdir="$1"
   if [ -z "${target_subdir}" ]; then
       target_subdir="${project_name}"
   fi
   local clone_dir="${EXP_DIR:?}/${target_subdir:?}"

   info "Cloning ${project_name}"

   local branch=""
   if [ -n "${git_branch}" ]; then
      branch="--branch ${git_branch}"
   fi

   rm -rf "${clone_dir:?}"

   # shellcheck disable=SC2086  # we want $git_options and $branch to expand into multiple arguments
   debug git clone ${git_options} ${branch} "${git_repo}" "${clone_dir}"

   # shellcheck disable=SC2086  # we want $git_options and $branch to expand into multiple arguments
   git clone ${git_options} ${branch} "${git_repo}" "${clone_dir}" || die "ERROR: Unable to clone git repository ${git_repo}"
   cd "${clone_dir}" || die "Unable to access git repository directory ${clone_dir}."
}

git_get_branch() {
  git symbolic-ref -q --short HEAD || echo "detached HEAD"
}

git_get_commit_id() {
  git rev-parse --verify HEAD
}

git_get_remote_url() {
  git remote get-url origin
}

git_checkout_commit() {
   local target_subdir="$1"
   if [ -z "${target_subdir}" ]; then
       target_subdir="${project_name}"
   fi
   local clone_dir="${EXP_DIR:?}/${target_subdir:?}"

  info "Cloning ${project_name} and checking out commit ${git_commit_id}"

  rm -rf "${clone_dir:?}"
  mkdir -p "${clone_dir}"
  cd "${clone_dir}" || die "ERROR: Unable to access git repository directory ${clone_dir}"
  git init > /dev/null || die "ERROR: Unable to initialize git"
  git remote add origin "${git_repo}" || die "ERROR: Unable to fetch from git repository ${git_repo}"

  if [[ "${#git_commit_id}" -lt 40 ]]; then
    # We have a short commit SHA. Unfortunately, we need the full commit history to fetch by a short SHA
    git fetch origin
    git -c advice.detachedHead=false checkout "${git_commit_id}"
  else
    if ! git fetch --depth 1 origin "${git_commit_id}"; then
      # Older versions of git don't support using --depth 1 with fetch, so try again without the shallow checkout
      git fetch origin "${git_commit_id}" || die "ERROR: Unable to fetch commit ${git_commit_id}"
    fi

    git -c advice.detachedHead=false checkout FETCH_HEAD || die "ERROR: Unable to checkout commit ${git_commit_id}"
  fi
}

read_git_metadata_from_current_repo() {
  git_repos+=("$(git_get_remote_url)")
  git_branches+=("${git_branch:-$(git_get_branch)}")
  git_commit_ids+=("$(git_get_commit_id)")
}
