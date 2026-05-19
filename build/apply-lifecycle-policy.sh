#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

TEMPLATE="${GITHUB_ACTION_PATH}/template-lifecycle-policy.json"

DEFAULT_KEEP_DAYS="30"
# DEFAULT_SNAPSHOT_KEEP_DAYS="30"
DEFAULT_PRERELEASE_KEEP_DAYS="90"
DEFAULT_DEMO_KEEP_DAYS="365"
# DEFAULT_DEVEL_KEEP_DAYS="30"

TYPES=( SNAPSHOT PRERELEASE DEMO DEVEL )

JQ_ARGS=()
for TYPE in "${TYPES[@]}" ; do
	# First, construt the variable name
	VAR="${TYPE}_KEEP_DAYS"

	# Compute the default
	DEF="DEFAULT_${VAR}"
	[ -v "${DEF}" ] && [[ "${!DEF}" =~ ^(0|[1-9][0-9]*)$ ]] && DEF="${!DEF}" || DEF="${DEFAULT_KEEP_DAYS}"

	# Validate the variable's value, and apply the default if invalid
	[ -v "${VAR}" ] && [[ "${!VAR}" =~ ^(0|[1-9][0-9]*)$ ]] || VAR="${DEF}"

	# Add the JQ arguments
	JQ_ARGS+=( --argjson "${VAR}" "${!VAR}" )
done

RC=0
JSON="$(mktemp --tmpdir="${GITHUB_ACTION_PATH}" "generated-lifecycle-policy-XXXXXXXX.json")" || fail "Failed to create a temporary file for the lifecycle policy"
CMD=( jq -n "${JQ_ARGS[@]}" -f "${TEMPLATE}" )
"${CMD[@]}" &>"${JSON}" || RC=${?}
[ "${RC}" -eq 0 ] || fail "Failed to render the lifecycle policy JSON (rc=${RC}): $(<"${JSON}")"

say "Checking the generated JSON syntax..."
OUT="$(jq -r < "${JSON}" 2>&1)" || RC=${?}
[ ${RC} -eq 0 ] || fail "The rendered JSON has errors (rc=${RC}): ${OUT}\n\n$(<"${JSON}")"

say "Applying the generated lifecycle policy:\n$(<"${JSON}")"
CMD=(
	aws ecr put-lifecycle-policy
		--region "${AWS_REGION}"
		--repository-name "${IMAGE_URI}"
		--lifecycle-policy-text "file://${JSON}"
)
is_local_dev && MODE="running" || MODE="execute"
"${MODE}" "${CMD[@]}"
