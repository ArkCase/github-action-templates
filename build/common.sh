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

# If there's no work directory, put it in the same directory as the action
[ -n "${WORK_DIR:-}" ] || export WORK_DIR="${GITHUB_ACTION_PATH}"

# If there's no pre-defined environment file, put it in the work directory
[ -n "${ENV_FILE:-}" ] || export ENV_FILE="${WORK_DIR}/.env"

if [ -f "${ENV_FILE}" ] ; then
	. "${ENV_FILE}"
	cat "${ENV_FILE}"
fi
