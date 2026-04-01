#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

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
