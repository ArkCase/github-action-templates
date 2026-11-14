#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

[ -n "${PUBLISHER_NAME:-}" ] || PUBLISHER_NAME="${GITHUB_TRIGGERING_ACTOR}"
[ -n "${PUBLISHER_EMAIL:-}" ] || PUBLISHER_EMAIL="${GITHUB_TRIGGERING_ACTOR}[bot]@workflow.github.com"

cd "${TGT_REPO_DIR}"
git config user.name "${PUBLISHER_NAME}"
git config user.email "${PUBLISHER_EMAIL}"
git add .
git commit -m "Publishing ${CHART_NAME}-${VERSION}"
git push
ok "Published ${CHART_NAME}-${VERSION}"
