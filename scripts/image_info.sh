#!/usr/bin/env bash
#
# Fetches information about a Fedora QEMU disk image from Fedora's mirrors.
#
# Arguments:
#   Version code of the desired Fedora Linux release (e.g. "f38")
#   (Optional) Machine architecture in the Linux format (e.g. "x86_64")

set -eu -o pipefail

source "${BASH_SOURCE[0]%/*}/lib/fedora.sh"
source "${BASH_SOURCE[0]%/*}/lib/util.sh"

declare os="${1?missing "'os'" positional parameter}"

declare arch
if (( $# == 2 )); then
	arch=$2
else
	arch="$(util::linux_arch)"
fi

declare img_url img_sha
img_url="$(fedora::image::url "$os" "$arch")"
img_sha="$(fedora::image::sha256sum "$img_url")"

declare img_data
img_data="$(jq -rnc \
	--arg url  "$img_url" \
	--arg sha  "$img_sha" \
	--arg arch "$arch" \
	'{"url": $url, "sha256sum": $sha, "arch": $arch}'
)"

echo "$img_data"
