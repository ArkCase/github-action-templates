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
	local PAGE="${2}"

	local RC=0
	local LIST=""
	LIST="$(run_gh "/repos/${GITHUB_REPOSITORY}/actions/artifacts?page=${PAGE}&per_page=100" 2>&1)" || RC=${?}
	if [ ${RC} != 0 ] ; then
		echo "${LIST}"
		return ${RC}
	fi

	# We filter by branch, name prefix, and run id so we don't
	# clobber artifacts being uploaded by this specific run, and
	# only delete artifacts added by other, older runs
	local FILTER='.artifacts[] | select(.workflow_run.head_branch==$BRANCH) | select(.workflow_run.id != $RUN_ID) | select(select(.name | test("^\($NAME_PREFIX)([^a-zA-Z0-9_].*)?$"))) | [ .id, .name, .size_in_bytes, .created_at, .workflow_run.id, .workflow_run.head_branch ] | @tsv'
	local CMD=(
		jq -r
			--argjson RUN_ID "${GITHUB_RUN_ID}"
			--arg BRANCH "${GITHUB_REF_NAME}"
			--arg NAME_PREFIX "${NAME_PREFIX}"
			"${FILTER}"
	)
	"${CMD[@]}" <<< "${LIST}" || return ${?}
	return 0
}

delete_artifact()
{
	local ARTIFACT_ID="${1}"
	run_gh "/repos/${GITHUB_REPOSITORY}/actions/artifacts/${ARTIFACT_ID}" "DELETE"
}

format_size()
{
	local SIZE="${1}"
	numfmt --to=iec-i --format="%.2f" <<< "${SIZE}"
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

	PAGE=0
	say "Deleting all the existing [${NAME_PREFIX}*] artifacts for the [${GITHUB_REF_NAME}] branch"
	while true ; do
		(( ++PAGE ))
		LIST="$(list_artifacts "${NAME_PREFIX}" "${PAGE}" 2>&1)" || fail "Failed to list the ${NAME_PREFIX} artifacts (page ${PAGE}) (rc=${?}): ${LIST}"

		[ -n "${LIST}" ] || break

		IDS=()
		while read LINE ; do
			[ -n "${LINE}" ] || continue
			read ID NAME SIZE CREATED_AT RUN_ID BRANCH <<< "${LINE}"
			echo "${LINE}"
			IDS+=( "${ID}" )
			(( TOTAL_SIZE += SIZE )) || true
		done <<< "${LIST}"
	done

	TOTAL_ARTIFACTS="${#IDS[@]}"
	running "Start deletion (${TOTAL_ARTIFACTS} artifacts found)..."
	for ID in "${IDS[@]}" ; do
		OUT="$(delete_artifact "${ID}" 2>&1)" || err "Failed to delete the artifact with ID ${ID} (rc=${?}): ${OUT}"
	done
	ok "Deleted $(format_size "${TOTAL_SIZE}")"
done
