#!/bin/bash

set -euo pipefail

to_env()
{
	cat >> "${ENV_FILE}"
}

to_github_env()
{
	[ -n "${GITHUB_ENV:-}" ] && cat >> "${GITHUB_ENV}"
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
