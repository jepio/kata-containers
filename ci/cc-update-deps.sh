#!/bin/bash

set -eux

BASE="$(dirname "$0")/../"
cd $BASE
pushd src/agent
rev=$(git ls-remote https://github.com/confidential-containers/image-rs HEAD | cut -f1)
sed -E -i -e 's/^image-rs(.*)rev = "[^"]*"(.*)/image-rs\1rev = "'"$rev"'"\2/' Cargo.toml

cargo update --package image-rs --precise "$rev"
popd
echo "::set-output name=image-rs-rev::$rev"

# get rid of
PATH=$PATH:$(go env GOPATH)/bin
update_version() {
  local url=$1
  local name=$2
  local var=$3
  rev=$(git ls-remote $url HEAD | cut -f1)
  # yq w --inplace versions.yaml 'externals.attestation-agent.version' "$rev"
  awk '
/'"$name"':/ { found = 1 }
found == 1 && /version:/ { gsub(/".*"/, "\"'$rev'\""); found = 0 }
{ print }
' versions.yaml >versions.yaml.tmp
  mv versions.yaml.tmp versions.yaml
  echo "::set-output name=$3::$rev"
}

update_version https://github.com/confidential-containers/attestation-agent attestation-agent aa-rev
update_version https://github.com/confidential-containers/td-shim td-shim td-shim
