#! /usr/bin/env bash

set -exuo pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
root_dir="${script_dir}/../../../.."
autoscaler_dir="${root_dir}/app-autoscaler-release"

function vendor-package {
  local release=${1}
  local package=${2}
  local version=${3}
  local package_location="$(pwd)/${release}"

  vendored_commit=$(cat "${release}/.git/ref")

  pushd "${autoscaler_dir}" > /dev/null
    # generate the private.yml file with the credentials
    echo "Generating private.yml..."
    cat > config/private.yml <<EOF
---
blobstore:
  options:
    credentials_source: static
    json_key:
EOF
    yq eval -i '.blobstore.options.json_key = strenv(UPLOADER_KEY)' config/private.yml

    bosh vendor-package "${package}" "${package_location}"
    echo "${vendored_commit}" >> "packages/${package}/vendored-commit"
    echo "${version}" >> "packages/${package}/version"
    echo "# Git diff -----"
    git --no-pager diff
  popd >/dev/null
}
