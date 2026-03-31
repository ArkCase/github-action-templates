#!/bin/bash
. "${GITHUB_ACTION_FILE}/common.sh"

JSON="$(mktemp --tmpdir="${GITHUB_ACTION_PATH}" "lifecycle-policy-XXXXXXXX.json")"
TEMPLATE="${GITHUB_ACTION_PATH}/lifecycle-policy-template.json"

RC=0
jq -n --arg DEVEL_KEEP_DAYS "${DEVEL_KEEP_DAYS}" --arg SNAPSHOT_KEEP_DAYS "${SNAPSHOT_KEEP_DAYS}" "$(<"${TEMPLATE}")" &>"${JSON}" || RC=${?}
if [ ${RC} -ne 0 ] ; then
	echo "ERROR: Failed to render the lifecycle policy JSON (rc=${RC}): $(<"${JSON}")"
	exit ${RC}
fi

aws ecr put-lifecycle-policy \
	--region "${AWS_REGION}" \
	--repository-name "${IMAGE_URI}" \
	--lifecycle-policy-text "file://${JSON}"
