#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

if [ -z "${HELM_REPO_URL:-}" ] ; then
	HELM_REPO_URL="$(gh api "repos/${GITHUB_REPOSITORY}/pages" --jq '.html_url')" || fail "Failed to compute the GitHub Pages URL (rc=${?}): ${HELM_REPO_URL}"

	# The charts are published within the public directory, so the URL must match
	PUBLIC_PATH="$(realpath -m --relative-to="${TGT_REPO_DIR}" "${CHART_TGT_DIR}")"
	[ "${PUBLIC_PATH}" == "." ] || HELM_REPO_URL="${HELM_REPO_URL%/}/${PUBLIC_PATH}"
fi

doing "Updating the repository index with the URL [${HELM_REPO_URL}]"
helm repo index --url "${HELM_REPO_URL}" "${CHART_TGT_DIR}"
