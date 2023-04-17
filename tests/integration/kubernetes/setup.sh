#!/usr/bin/env bash
# Copyright (c) 2023 Microsoft Corporation
#
# SPDX-License-Identifier: Apache-2.0

set -x
set -o errexit
set -o nounset
set -o pipefail

kubernetes_dir=$(dirname "$(readlink -f "$0")")
repo_root_dir="$(cd "${kubernetes_dir}/../../../" && pwd)"
source "${repo_root_dir}/tools/packaging/scripts/lib.sh"

set_runtime_class() {
    sed -i -e "s|runtimeClassName: kata|runtimeClassName: kata-${KATA_HYPERVISOR}|" ${kubernetes_dir}/runtimeclass_workloads/*.yaml
}

set_initrd_path() {
    arch="$(uname -m)"
    img_distro="$(get_from_kata_deps "assets.initrd.host_os.${KATA_HOST_OS}.architecture.${arch}.name")"
    img_os_version="$(get_from_kata_deps "assets.initrd.host_os.${KATA_HOST_OS}.architecture.${arch}.version")"
    initrd_name="kata-${img_distro}-${img_os_version}.initrd"
    initrd_path="/opt/kata/share/kata-containers/${initrd_name}"
    find ${kubernetes_dir}/runtimeclass_workloads/*.yaml -exec yq write -i {} 'metadata.annotations[io.katacontainers.config.hypervisor.initrd]' "${initrd_path}" \;
}

main() {
    bash "${repo_root_dir}/ci/install_yq.sh"
    yq --version
    which yq
    echo $PATH
    echo ${GOPATH:-}
    echo ${INSTALL_IN_GOPATH:-}
    set_runtime_class
    set_initrd_path
}

main "$@"
