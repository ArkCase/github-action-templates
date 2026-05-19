#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

run_gh()
{
	local URI="${1}"
	local METHOD="${2:-}"
	if [ -n "${METHOD}" ] ; then
		METHOD=(--method "${METHOD}")
	else
		METHOD=()
	fi
	gh api \
		"${METHOD[@]}" \
		-H "Accept: application/vnd.github+json" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"${URI}"
}

list_artifacts()
{
	local NAME_PREFIX="${1}"
	local FILTER='.artifacts[] | select(.workflow_run.head_branch==$BRANCH) | select(select(.name | test("^\($NAME_PREFIX)([^a-zA-Z0-9_].*)?$"))) | [ .id, .name, .size_in_bytes, .created_at ] | @tsv'
	run_gh "/repos/${GITHUB_REPOSITORY}/actions/artifacts" | \
			jq -r --arg BRANCH "${GITHUB_REF_NAME}" --arg NAME_PREFIX "${NAME_PREFIX}" "${FILTER}"
}

delete_artifact()
{
	local ARTIFACT_ID="${1}"
	# run_gh "/repos/${GITHUB_REPOSITORY}/actions/artifacts/${ARTIFACT_ID}" "DELETE"

	# For debugging: output the URI that would be called ...
	echo "/repos/${GITHUB_REPOSITORY}/actions/artifacts/${ARTIFACT_ID}" "DELETE"
	return 1
}

#
# Let's now do the deed!
#

TYPES=(
	VULN:vulnerabilities
	COMP:compliance
)

TOTAL_SIZE="0"
for TYPE in "${TYPES[@]}" ; do
	IFS=":" read TYPE NAME_PREFIX <<< "${TYPE}"

	VAR="SCAN_${TYPE}"
	[ -v "${VAR}" ] || continue
	VAR="${!VAR}"
	[ "${VAR,,}" == "true" ] || continue

	LIST="$(list_artifacts "${NAME_PREFIX}" 2>&1)" || fail "Failed to list the ${NAME_PREFIX} artifacts (rc=${?}): ${LIST}"

	IDS=()
	say "Deleting all the existing [${NAME_PREFIX}*] artifacts for the [${GITHUB_REF_NAME}] branch"
	while read LINE ; do
		[ -n "${LINE}" ] || continue
		read ID NAME SIZE CREATED_AT <<< "${LINE}"
		echo "${LINE}"
		IDS+=( "${ID}" )
		(( TOTAL_SIZE += SIZE )) || true
	done <<< "${LIST}"

	running "Start deletion..."
	for ID in "${IDS[@]}" ; do
		OUT="$(delete_artifact "${ID}" 2>&1)" || err "Failed to delete the artifact with ID ${ID} (rc=${?}): ${OUT}"
	done
	ok "Deleted ${#IDS[@]} existing artifacts"
done
