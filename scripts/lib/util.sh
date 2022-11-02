# Returns the machine architecture in Linux format.
#
# Arguments:
#   None
# Outputs:
#   Machine architecture in the Linux format (e.g. "x86_64")
util::linux_arch() {
	local arch
	arch="$(arch)" || return

	local os
	os="$(uname -s)" || return

	if [[ "$os" == Linux ]]; then
		echo "$arch"
		return
	fi

	case "$arch" in
		arm64)
			echo aarch64
			;;
		*)
			echo x86_64
			;;
	esac
}
