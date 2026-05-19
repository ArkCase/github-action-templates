#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

# Disable for now - we need a cleaner way. When running parallel builds
# (i.e. with multi-version builds), this might clear out the artifacts
# just uploaded by other builds running in parallel, so it becomes a race
# to see who survives.
#
# This is CLEARLY not what we want, so we need to figure out the clean way to
# do this so we can clear out ALL the artifacts for ALL the builds launched
# prior to this *OVERALL* build (i.e. including all parallel builds), while
# also doing so at the last possible moment so we only do it if the build
# was successful AND a scan (of the corresponding type) was requested and
# successful... at that moment we would delete whatever needs deleting,
# and replace it with whatever needs replacing.
#
# We need to figure out how to determine that, and at that point we can
# proceed to delete the old crap to only keep the very latest.
#
exit 0

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
	run_gh "/repos/${GITHUB_REPOSITORY}/actions/artifacts/${ARTIFACT_ID}" "DELETE"
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
