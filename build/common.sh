#!/bin/bash

set -euo pipefail

has_value()
{
	local DECL="${1}"
	[[ "${DECL}" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]] && return 0
	return 1
}

to_env()
{
	local KEY=""
	local VALUE=""
	local DECL=""

	for VAR in "${@}" ; do
		# If it's a full declaration,
		if has_value "${VAR}" ; then
			KEY="${BASH_REMATCH[1]}"
			VALUE="${BASH_REMATCH[2]}"
		else
			KEY="${VAR}"
			VALUE="${!VAR:-}"
		fi
		DECL="${KEY}=${VALUE}"
		declare -xg "${DECL}"
		echo "${DECL}" >> "${GITHUB_ENV}"
	done
}
