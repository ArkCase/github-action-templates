#!/bin/bash

set -euo pipefail

if [ -z "${GITHUB_ACTION_PATH:-}" ] ; then
    THIS_SCRIPT="$(readlink -f "${BASH_ARGV0:${BASH_SOURCE:-${0}}}")"
    export GITHUB_ACTION_PATH="$(dirname "${THIS_SCRIPT}")"
fi

# If there's no work directory, put it in the same directory as the action
[ -n "${WORK_DIR:-}" ] || export WORK_DIR="${GITHUB_ACTION_PATH}"

# If there's no pre-defined environment file, put it in the work directory
[ -n "${ENV_FILE:-}" ] || export ENV_FILE="${WORK_DIR}/.env"

. "${ENV_FILE}"

JSON="$(mktemp --tmpdir="${GITHUB_ACTION_PATH}" "permissions-XXXXXXXX.json")"
TEMPLATE="${GITHUB_ACTION_PATH}/permissions-template.json"

RC=0
jq -n --arg AWS_ORG_ID "${AWS_ORG_ID}" "$(<"${TEMPLATE}")" &>"${JSON}" || RC=${?}
if [ ${RC} -ne 0 ] ; then
	echo "ERROR: Failed to render the permissions JSON (rc=${RC}): $(<"${JSON}")"
	exit ${RC}
fi

aws ecr set-repository-policy \
	--region "${AWS_REGION}" \
	--repository-name "${IMAGE_URI}" \
	--policy-text "file://${JSON}"
