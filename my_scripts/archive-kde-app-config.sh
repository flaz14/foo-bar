#!/bin/bash

set -e

readonly kde_home_directory='.kde'

# Trick that helps to abort the whole script
# from any function.
trap 'exit 1' TERM
export TOP_PID=$$
function abort() {
	kill -s TERM $TOP_PID
}

function print_usage_info() {
	local script_name="$(basename "$0")"
	cat <<-EOF

		Usage: 
		
		$script_name PATTERN

		Gathers all user-configuration files which are related 
		to specified KDE application. Then packs them into 
		tar-archive and sends it to standard output.
		
		Note that typical KDE application is build upon several 
		KDE components. So don't be suprised in case when, for
		example, you specify 'kate' as PATTERN and see something 
		like '.kde/share/apps/kdevelop/katepartui.rc' in the 
		resultant tarball.

	EOF
	abort
}

function check_pattern() {
	local pattern="$1"
	if [[ -z "$pattern" ]]; then
		echo 'PATTERN should not be empty.'
		print_usage_info
	fi
	if [[ -n "$2" ]]; then 
		echo "Only one argument should be specified."
		print_usage_info
	fi
	local does_contain_k="$(echo "$pattern" | grep -i 'K')"
	if [[ -z "$does_contain_k" ]]; then
		cat <<-EOF 
			Specified PATTERN doesn't contain K letter.
			Perhaps, this pattern doesn't correspond to 
			any KDE application.
		EOF
		print_usage_info
	fi
}

function pack_configuration_files() {
	local pattern="$1"
	# all paths will start from '.kde' 
	cd ~
	local paths="$(find "$kde_home_directory" \
			-path "*$pattern*"                \
			-print0                           \
			2>/dev/null)"
	if [[ -z "$paths" ]]; then
		echo "Nothing found for $pattern. Abort."
		abort
	fi
	# find files one more time in order to preserve NULL 
	# separators (NULL-characters cannot be saved in Bash 
	# variable, so we cannot reuse $paths)
	find "$kde_home_directory" \
	-path "*$pattern*"         \
	-print0                    \
	2>/dev/null                \
	| tar --create --null --files-from - 
}

function main() {
	check_pattern "$1" "$2"
	pack_configuration_files "$1"
}

main "$1" "$2"