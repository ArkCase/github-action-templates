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
		declare -xg "${KEY}=${VALUE}"
		declare -p "${KEY}" >> "${ENV_FILE}"
		[ -n "${GITHUB_ENV:-}" ] && echo "${KEY}=${VALUE}" >> "${GITHUB_ENV}"
	done
}

if [ -z "${GITHUB_ACTION_PATH:-}" ] ; then
	THIS_SCRIPT="$(readlink -f "${BASH_ARGV0:-${BASH_SOURCE:-${0}}}")"
	export GITHUB_ACTION_PATH="$(dirname "${THIS_SCRIPT}")"
fi

# If there's no pre-defined environment file, put it in the work directory
[ -n "${ENV_FILE:-}" ] || export ENV_FILE="${GITHUB_ACTION_PATH}/.env"

if [ -f "${ENV_FILE}" ] ; then
	. "${ENV_FILE}"
	cat "${ENV_FILE}"
fi
