#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

TEMPLATE="${GITHUB_ACTION_PATH}/template-permissions.json"

DEFAULT_AWS_ORG_ID="(unknown)"
[ -n "${AWS_ORG_ID:-}" ] || AWS_ORG_ID="${DEFAULT_AWS_ORG_ID}"

CMD=(
	jq -n
		--arg AWS_ORG_ID "${AWS_ORG_ID}"
)

JSON="$(mktemp --tmpdir="${GITHUB_ACTION_PATH}" "generated-permissions-XXXXXXXX.json")"

RC=0
"${CMD[@]}" "$(<"${TEMPLATE}")" >"${JSON}" || RC=${?}
[ ${RC} -eq 0 ] || fail "Failed to render the permissions JSON (rc=${RC}): $(<"${JSON}")"

say "Checking the generated JSON syntax..."
OUT="$(jq -r < "${JSON}" 2>&1)" || RC=${?}
[ ${RC} -eq 0 ] || fail "The rendered JSON has errors (rc=${RC}): ${OUT}\n\n$(<"${JSON}")"

say "Applying the generated repository permissions:\n$(<"${JSON}")"
CMD=(
	aws ecr set-repository-policy
		--region "${AWS_REGION}"
		--repository-name "${IMAGE_URI}"
		--policy-text "file://${JSON}"
)
is_local_dev && MODE="running" || MODE="execute"
"${MODE}" "${CMD[@]}"
