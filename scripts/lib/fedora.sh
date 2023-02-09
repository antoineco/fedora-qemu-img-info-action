# Returns the URL of a Fedora QEMU disk image.
#
# Arguments:
#   OS version in the format f<version_id> (e.g. "f38")
#   Machine architecture in the Linux format (e.g. "x86_64")
# Outputs:
#   Image URL
fedora::image::url() {
	local os=$1
	local arch=$2

	local os_version_id="${os#f}"
	local os_codename="$os_version_id"
	if (( os_version_id > 38 )); then
		os_codename=rawhide
	fi

	local mirrorlist_url="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-${os_version_id}&arch=${arch}"

	>&2 echo "::debug::Probing mirrorlist URL ${mirrorlist_url}"

	local mirror_url=''
	local imgpath=''

	# read exits with a non-zero code if the last read input doesn't end
	# with a newline character. The printf without newline that follows the
	# curl command ensures that the final input not only contains curl's
	# exit code, but causes read to fail so we can capture the return value.
	# Ref. https://unix.stackexchange.com/a/176703/152409
	local line
	local -i return_outer
	local -i return_inner
	local -i imglist_code
	local -i close_body=0
	while IFS= read -r line || ! return_outer="$line"; do
		if (( close_body )); then
			# read the remaining response body to avoid printing
			# harmless but misleading errors:
			#   curl: (23) Failed writing body (495 != 1635)
			#   printf: write error: Broken pipe
			continue
		fi

		>&2 echo "::debug::Evaluating line ${line}"
		if [[ ! "$line" =~ ^(https?://.+/fedora) ]]; then
			continue
		fi

		mirror_url="${BASH_REMATCH[1]}"

		# Check whether mirror has imagelist file, otherwise it
		# is not a valid candidate.
		>&2 echo "::debug::Checking whether mirror has imagelist: ${mirror_url}"
		imglist_code="$(curl -sSI -o /dev/null -w '%{http_code}' "$mirror_url"/imagelist-fedora)" || return
		if (( imglist_code != 200 )); then
			>&2 echo "Mirror is not serving imagelist, skipping: ${mirror_url}"
			continue
		fi

		>&2 echo "::debug::Probing imagelist file at URL ${mirror_url}/imagelist-fedora"

		while IFS= read -r line || ! return_inner="$line"; do
			if (( close_body )); then
				continue
			fi
			>&2 echo "::debug::Evaluating line ${line}"
			if [[ "$line" =~ (linux\/[a-z]+\/${os_codename}\/Cloud\/${arch}\/images\/.+\.qcow2) ]]; then
				imgpath="${BASH_REMATCH[1]}"
				>&2 echo "Found matching image ${mirror_url}/${imgpath}"
				close_body=1
			fi
		done < <(curl -sSf "$mirror_url"/imagelist-fedora; printf '%s' "$?")

		if (( return_inner )); then
			>&2 echo "Failed to get the page ${mirror_url}/imagelist-fedora"
			return "$return_inner"
		fi
	done < <(curl -sSf "$mirrorlist_url"; printf '%s' "$?")

	if (( return_outer )); then
		>&2 echo "Failed to get the page ${mirrorlist_url}"
		return "$return_outer"
	fi

	if [[ -z "$mirror_url" ]]; then
		>&2 echo "Couldn't find a mirror for OS version '${os}' and architecture '${arch}'"
		return 1
	fi

	if [[ -z "$imgpath" ]]; then
		>&2 echo "Couldn't find an image for OS version '${os}' and architecture '${arch}'"
		return 1
	fi

	echo "${mirror_url}/${imgpath}"
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
