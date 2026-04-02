#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

TEMPLATE="${GITHUB_ACTION_PATH}/permissions-template.json"

DEFAULT_AWS_ORG_ID="(unknown)"
[ -n "${AWS_ORG_ID:-}" ] || AWS_ORG_ID="${DEFAULT_AWS_ORG_ID}"

CMD=(
	jq -n
		--arg AWS_ORG_ID "${AWS_ORG_ID}"
)

JSON="$(mktemp --tmpdir="${GITHUB_ACTION_PATH}" "generated-permissions-XXXXXXXX.json")"

RC=0
"${CMD[@]}" "$(<"${TEMPLATE}")" &>"${JSON}" || RC=${?}
if [ ${RC} -ne 0 ] ; then
	echo "ERROR: Failed to render the permissions JSON (rc=${RC}): $(<"${JSON}")"
	exit ${RC}
fi

echo "Checking the generated JSON syntax..."
OUT="$(jq -r < "${JSON}" 2>&1)" || RC=${?}
if [ ${RC} -ne 0 ] ; then
	echo "ERROR: The rendered JSON has errors (rc=${RC}): ${OUT}\n\n$(<"${JSON}")"
	exit ${RC}
fi

echo -e "Applying the generated repository permissions:\n$(<"${JSON}")"
exec aws ecr set-repository-policy \
	--region "${AWS_REGION}" \
	--repository-name "${IMAGE_URI}" \
	--policy-text "file://${JSON}"
