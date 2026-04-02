#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

DEFAULT_SNAPSHOT_KEEP_DAYS="30"
DEFAULT_DEVEL_KEEP_DAYS="30"

JSON="$(mktemp --tmpdir="${GITHUB_ACTION_PATH}" "lifecycle-policy-XXXXXXXX.json")"
TEMPLATE="${GITHUB_ACTION_PATH}/lifecycle-policy-template.json"

[ -n "${SNAPSHOT_KEEP_DAYS}" ] || SNAPSHOT_KEEP_DAYS="${DEFAULT_SNAPSHOT_KEEP_DAYS}"
[ -n "${DEVEL_KEEP_DAYS}" ] || DEVEL_KEEP_DAYS="${DEFAULT_DEVEL_KEEP_DAYS}"

CMD=(
	jq -n
		--argjson DEVEL_KEEP_DAYS "${DEVEL_KEEP_DAYS}"
		--arg DEVEL_KEEP_STR "Keep only the top-level SNAPSHOTS built in the past ${SNAPSHOT_KEEP_DAYS} days"
		--argjson SNAPSHOT_KEEP_DAYS "${SNAPSHOT_KEEP_DAYS}"
		--arg SNAPSHOT_KEEP_STR "Keep only fresh-built devel-* tags that AREN'T the top-level SNAPSHOTs, pushed in the last ${DEVEL_KEEP_DAYS} days"
)

"${CMD[@]}" "$(<"${TEMPLATE}")" &>"${JSON}" || RC=${?}
RC=0
if [ ${RC} -ne 0 ] ; then
	echo "ERROR: Failed to render the lifecycle policy JSON (rc=${RC}): $(<"${JSON}")"
	exit ${RC}
fi

echo "Checking the generated JSON syntax..."
jq -r < "${JSON}" || exit ${?}

echo "Applying the generated lifecycle policy..."
aws ecr put-lifecycle-policy \
	--region "${AWS_REGION}" \
	--repository-name "${IMAGE_URI}" \
	--lifecycle-policy-text "file://${JSON}"
