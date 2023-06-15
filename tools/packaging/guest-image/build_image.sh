#!/usr/bin/env bash
#
# Copyright (c) 2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

[ -z "${DEBUG}" ] || set -x

set -o errexit
set -o nounset
set -o pipefail

readonly script_name="$(basename "${BASH_SOURCE[0]}")"
readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly packaging_root_dir="$(cd "${script_dir}/../" && pwd)"

source "${packaging_root_dir}/scripts/lib.sh"

readonly osbuilder_dir="$(cd "${repo_root_dir}/tools/osbuilder" && pwd)"

export GOPATH=${GOPATH:-${HOME}/go}

arch_target="$(uname -m)"
final_image_name="kata-containers"
final_initrd_name="kata-containers-initrd"
image_initrd_extension=".img"

build_initrd() {
	info "Build initrd"
	info "default host os: $is_default"
	info "initrd os: $os_name"
	info "initrd os version: $os_version"
	sudo -E PATH="$PATH" make initrd \
		DISTRO="$os_name" \
		DEBUG="${DEBUG:-}" \
		OS_VERSION="${os_version}" \
		ROOTFS_BUILD_DEST="${builddir}/initrd-image" \
		USE_DOCKER=1 \
		AGENT_INIT="yes"
	mv "kata-containers-initrd.img" "${install_dir}/${artifact_name}"
	# Only symlink for the default host OS to avoid unintentionally overriding
	# the link in case we build out of order.
	if [ "${is_default}" = "yes" ]; then
		(
			cd "${install_dir}"
			ln -sf "${artifact_name}" "${final_initrd_name}${image_initrd_extension}"
		)
	fi
}

build_image() {
	info "Build image"
	info "default host os: $is_default"
	info "image os: $os_name"
	info "image os version: $os_version"
	sudo -E PATH="${PATH}" make image \
		DISTRO="${os_name}" \
		DEBUG="${DEBUG:-}" \
		USE_DOCKER="1" \
		IMG_OS_VERSION="${os_version}" \
		ROOTFS_BUILD_DEST="${builddir}/rootfs-image"
	mv -f "kata-containers.img" "${install_dir}/${artifact_name}"
	if [ -e "root_hash.txt" ]; then
	    cp root_hash.txt "${install_dir}/"
	fi
	# Only symlink for the default host OS to avoid unintentionally overriding
	# the link in case we build out of order.
	if [ -z "${image_initrd_suffix}" ]; then
		(
			cd "${install_dir}"
			ln -sf "${artifact_name}" "${final_image_name}${image_initrd_extension}"
		)
	fi
}

usage() {
	return_code=${1:-0}
	cat <<EOF
Create image and initrd in a tarball for kata containers.
Use it to build an image to distribute kata.

Usage:
${script_name} [options]

Options:
 --osname=${os_name}
 --osversion=${os_version}
 --imagetype=${image_type}
 --prefix=${prefix}
 --destdir=${destdir}
 --image_initrd_suffix=${image_initrd_suffix}
EOF

	exit "${return_code}"
}

main() {
	image_type=image
	destdir="$PWD"
	prefix="/opt/kata"
	image_suffix=""
	image_initrd_suffix=""
	builddir="${PWD}"
	while getopts "h-:" opt; do
		case "$opt" in
		-)
			case "${OPTARG}" in
			isdefault=*)
				is_default=${OPTARG#*=}
				;;
			osname=*)
				os_name=${OPTARG#*=}
				;;
			osversion=*)
				os_version=${OPTARG#*=}
				;;
			imagetype=image)
				image_type=image
				;;
			imagetype=initrd)
				image_type=initrd
				;;
			image_initrd_suffix=*)
				image_initrd_suffix=${OPTARG#*=}
				;;
			prefix=*)
				prefix=${OPTARG#*=}
				;;
			destdir=*)
				destdir=${OPTARG#*=}
				;;
			builddir=*)
				builddir=${OPTARG#*=}
				;;
			*)
				echo >&2 "ERROR: Invalid option -$opt${OPTARG}"
				usage 1
				;;
			esac
			;;
		h) usage 0 ;;
		*)
			echo "Invalid option $opt"
			usage 1
			;;
		esac
	done
	readonly destdir
	readonly builddir

	echo "build ${image_type}"

	if [ "${image_initrd_suffix}" == "sev" ]; then
		artifact_name="kata-${os_name}-${os_version}-${image_initrd_suffix}.${image_type}"
		final_initrd_name="${final_initrd_name}-${image_initrd_suffix}"
	elif [ "${image_initrd_suffix}" == "tdx" ]; then
		artifact_name="kata-${os_name}-${os_version}-${image_initrd_suffix}.${image_type}"
		final_image_name="${final_image_name}-${image_initrd_suffix}"
	else
		artifact_name="kata-${os_name}-${os_version}.${image_type}"
	fi

	install_dir="${destdir}/${prefix}/share/kata-containers/"
	readonly install_dir

	mkdir -p "${install_dir}"

	pushd "${osbuilder_dir}"
	case "${image_type}" in
	initrd) build_initrd ;;
	image) build_image ;;
	esac

	popd
}

main $*
