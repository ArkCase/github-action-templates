#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

TEMPLATE="${GITHUB_ACTION_PATH}/lifecycle-policy-template.json"

DEFAULT_SNAPSHOT_KEEP_DAYS="30"
[ -n "${SNAPSHOT_KEEP_DAYS:-}" ] || SNAPSHOT_KEEP_DAYS="${DEFAULT_SNAPSHOT_KEEP_DAYS}"

DEFAULT_DEVEL_KEEP_DAYS="30"
[ -n "${DEVEL_KEEP_DAYS:-}" ] || DEVEL_KEEP_DAYS="${DEFAULT_DEVEL_KEEP_DAYS}"

CMD=(
	jq -n
		--argjson DEVEL_KEEP_DAYS "${DEVEL_KEEP_DAYS}"
		--arg DEVEL_KEEP_STR "Keep only the top-level SNAPSHOTS built in the past ${SNAPSHOT_KEEP_DAYS} days"
		--argjson SNAPSHOT_KEEP_DAYS "${SNAPSHOT_KEEP_DAYS}"
		--arg SNAPSHOT_KEEP_STR "Keep only fresh-built devel-* tags that AREN'T the top-level SNAPSHOTs, pushed in the last ${DEVEL_KEEP_DAYS} days"
)

JSON="$(mktemp --tmpdir="${GITHUB_ACTION_PATH}" "generated-lifecycle-policy-XXXXXXXX.json")"

RC=0
"${CMD[@]}" "$(<"${TEMPLATE}")" &>"${JSON}" || RC=${?}
if [ ${RC} -ne 0 ] ; then
	echo "ERROR: Failed to render the lifecycle policy JSON (rc=${RC}): $(<"${JSON}")"
	exit ${RC}
fi

echo "Checking the generated JSON syntax..."
OUT="$(jq -r < "${JSON}" 2>&1)" || RC=${?}
if [ ${RC} -ne 0 ] ; then
	echo "ERROR: The rendered JSON has errors (rc=${RC}): ${OUT}\n\n$(<"${JSON}")"
	exit ${RC}
fi

echo -e "Applying the generated lifecycle policy:\n$(<"${JSON}")"
exec aws ecr put-lifecycle-policy \
	--region "${AWS_REGION}" \
	--repository-name "${IMAGE_URI}" \
	--lifecycle-policy-text "file://${JSON}"
