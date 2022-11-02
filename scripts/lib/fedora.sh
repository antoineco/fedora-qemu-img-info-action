# Returns the URL of a Fedora QEMU disk image.
#
# Arguments:
#   OS version in the format f<version_id> (e.g. "f37")
#   Machine architecture in the Linux format (e.g. "x86_64")
# Outputs:
#   Image URL
fedora::image::url() {
	local os=$1
	local arch=$2

	local base_url
	base_url="$(fedora::mirror "$os" "$arch")" || return
	local imglist_url="$base_url"/imagelist-fedora

	os="${os#f}"
	(( os > 37 )) && os=rawhide

	>&2 echo "::debug::Probing imagelist file at URL ${imglist_url}"

	local imgpath

	# read exits with a non-zero code if the last read input doesn't end
	# with a newline character. The printf without newline that follows the
	# curl command ensures that the final input not only contains curl's
	# exit code, but causes read to fail so we can capture the return value.
	# Ref. https://unix.stackexchange.com/a/176703/152409
	local line
	local -i return
	local -i close_body=0
	while IFS= read -r line || ! return="$line"; do
		if (( close_body )); then
			# read the remaining response body to avoid printing
			# harmless but misleading errors:
			#   curl: (23) Failed writing body (495 != 1635)
			#   printf: write error: Broken pipe
			continue
		fi
		>&2 echo "::debug::Evaluating line ${line}"
		if [[ "$line" =~ (linux\/[a-z]+\/${os}\/Cloud\/${arch}\/images\/.+\.qcow2) ]]; then
			>&2 echo "Found matching image ${line}"
			imgpath="${BASH_REMATCH[1]}"
			close_body=1
		fi
	done < <(curl -sSf "$imglist_url"; printf '%s' "$?")

	if (( return )); then
		>&2 echo "Failed to get the page ${imglist_url}"
		return "$return"
	fi

	if [[ -z "$imgpath" ]]; then
		>&2 echo "Couldn't find an image for OS version '${os}' and architecture '${arch}'"
		return 1
	fi

	echo "${base_url}/${imgpath}"
}

# Returns the expected SHA256 checksum of a Fedora QEMU disk image.
#
# Arguments:
#   Image URL
# Outputs:
#   SHA256 checksum
fedora::image::sha256sum() {
	local url=$1

	local checksum_url
	if [[ "$url" =~ ^(.*)\/Fedora-Cloud-Base-([A-Za-z0-9]+)-([0-9a-z\.-]+)\.([a-z0-9_]+).qcow2$ ]]; then
		local base="${BASH_REMATCH[1]}"
		local os="${BASH_REMATCH[2]}"
		local id="${BASH_REMATCH[3]}"
		local arch="${BASH_REMATCH[4]}"

		if [[ "$url" =~ \/releases\/ ]]; then
			checksum_url="${base}/Fedora-Cloud-${os}-${id}-${arch}-CHECKSUM"
		else
			checksum_url="${base}/Fedora-Cloud-${os}-${arch}-${id}-CHECKSUM"
		fi
	fi

	local img_name="${url##*/}"

	if [[ -z "$checksum_url" ]]; then
		>&2 echo "Couldn't determine checksum file for image ${img_name}"
		return 1
	fi

	>&2 echo "::debug::Probing checksum file at URL ${checksum_url}"

	local sha256sum

	# See fedora::image::url for an explanation of this arcane error
	# handling method.
	local line
	local -i return
	local -i close_body=0
	while IFS= read -r line || ! return="$line"; do
		if (( close_body )); then
			continue
		fi
		>&2 echo "::debug::Evaluating line ${line}"
		if [[ "$line" =~ ^SHA256\ \(${img_name}\)\ \=\ (.*) ]]; then
			>&2 echo "Found image checksum ${line}"
			sha256sum="${BASH_REMATCH[1]}"
			close_body=1
		fi
	done < <(curl -sSf "$checksum_url"; printf '%s' "$?")

	if (( return )); then
		>&2 echo "Failed to get the page ${checksum_url}"
		return "$return"
	fi

	if [[ -z "$sha256sum" ]]; then
		>&2 echo "Couldn't determine checksum for image ${img_name} from file ${checksum_url##*/}"
		return 1
	fi

	echo "$sha256sum"
}

# Returns the base URL of a suitable Fedora mirror.
#
# Arguments:
#   OS version in the format f<version_id> (e.g. "f37")
#   Machine architecture in the Linux format (e.g. "x86_64")
# Outputs:
#   Mirror base URL (e.g. "https://mirror.example.com/fedora")
fedora::mirror() {
	local os=$1
	local arch=$2

	local mirrorlist_url="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-${os#f}&arch=${arch}"

	>&2 echo "::debug::Probing mirrorlist URL ${mirrorlist_url}"

	local mirror_url

	# See fedora::image::url for an explanation of this arcane error
	# handling method.
	local line
	local -i return
	local -i imglist_code
	local -i close_body=0
	while IFS= read -r line || ! return="$line"; do
		if (( close_body )); then
			continue
		fi
		>&2 echo "::debug::Evaluating line ${line}"
		if [[ "$line" =~ ^(https?://.+/fedora) ]]; then
			mirror_url="${BASH_REMATCH[1]}"
			# Check whether mirror has imagelist file, otherwise it
			# is not a valid candidate.
			>&2 echo "::debug::Checking whether mirror has imagelist ${line}"
			imglist_code="$(curl -sSI -o /dev/null -w '%{http_code}' "$mirror_url"/imagelist-fedora)" || return
			if (( imglist_code == 200 )); then
				>&2 echo "Found suitable mirror ${line}"
				close_body=1
			fi
		fi
	done < <(curl -sSf "$mirrorlist_url"; printf '%s' "$?")

	if (( return )); then
		>&2 echo "Failed to get the page ${mirrorlist_url}"
		return "$return"
	fi

	if [[ -z "$mirror_url" ]]; then
		>&2 echo "Couldn't find a mirror for OS version ${os} and architecture ${arch}"
		return 1
	fi

	echo "$mirror_url"
}
