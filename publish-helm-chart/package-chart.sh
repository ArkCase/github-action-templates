#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

# Make sure no symlinks take the publication target outside of the GH Pages checkout
ensure_inside "${TGT_REPO_DIR}" "${CHART_TGT_DIR}" "public directory"
ensure_inside "${TGT_REPO_DIR}" "${CHART_TGT_DIR}/${CHART_TGT_FILE}" "chart package"

if [ -e "${CHART_TGT_DIR}/${CHART_TGT_FILE}" ] ; then
	# The tag must survive this failure, since it's for an existing release
	to_env DELETE_TAG="false"
	fail "Version ${VERSION} of chart [${CHART_NAME}] has already been published. Overwrite is not allowed."
fi

RC=0
OUT="$(helm package --destination "${CHART_TGT_DIR}" --dependency-update "${CHART_SRC_DIR}/${CHART_NAME}" 2>&1)" || RC="${?}"
[ "${RC}" -eq 0 ] || fail "Failed to package the chart (rc=${RC}): ${OUT}"

# Packaging complete, get the name of the file packaged
OUT_RE='^.*to: (.*[.]tgz)$'
[[ "${OUT}" =~ ${OUT_RE} ]] || fail "Unexpected output from 'helm package': ${OUT}"
PACKAGED_CHART="$(basename "${BASH_REMATCH[1]}")"

# The packaged chart should be in the file "${CHART_TGT_DIR}/${CHART_TGT_FILE}"
[ "${PACKAGED_CHART}" == "${CHART_TGT_FILE}" ] || fail "The packaged chart's name (${PACKAGED_CHART}) did not match the expected name (${CHART_TGT_FILE})"
ok "Packaged the chart as [${CHART_TGT_DIR}/${CHART_TGT_FILE}]"
