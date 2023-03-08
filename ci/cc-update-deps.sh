#!/bin/bash

set -eux

set_output() {
  if [ -z "${GITHUB_OUTPUT}" ];
    return
  fi
  echo "$1=$2" >> "${GITHUB_OUTPUT}"
}

cidir=$(dirname "$0")
cd "$cidir"/..

pushd src/agent
rev=$(git ls-remote https://github.com/confidential-containers/image-rs HEAD | cut -f1)
sed -E -i -e 's/^image-rs(.*)rev = "[^"]*"(.*)/image-rs\1rev = "'"$rev"'"\2/' Cargo.toml

cargo update --package image-rs --precise "$rev"
popd
set_output "image-rs-rev" "$rev"

# This would use yq but yq changes the layout of the file
update_version() {
  local url=$1
  local name=$2
  local var=$3
  rev=$(git ls-remote $url HEAD | cut -f1)
  awk '
/'"$name"':/ { found = 1 }
found == 1 && /version:/ { gsub(/".*"/, "\"'$rev'\""); found = 0 }
{ print }
' versions.yaml >versions.yaml.tmp
  mv versions.yaml.tmp versions.yaml
  set_output "$3" "$rev"
}

update_version https://github.com/confidential-containers/attestation-agent attestation-agent aa-rev
update_version https://github.com/confidential-containers/td-shim td-shim td-shim
