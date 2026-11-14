#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

[ "${DELETE_TAG:-}" == "true" ] || quit "Tag deletion has been bypassed"

warn "Deleting the tag [${GITHUB_REF}] after the failed run"
git -C "${SRC_REPO_DIR}" push --delete origin "${GITHUB_REF}"
