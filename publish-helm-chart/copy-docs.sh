#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

# Add the documentation, if needed
[ -d "${DOC_SRC_DIR}" ] || quit "No documentation found at [${DOC_SRC_DIR}]"

# Never copy git metadata, lest we clobber the target repository's
doing "Copying the documentation"
( cd "${DOC_SRC_DIR}" && tar --exclude=".git" -cf - . ) | tar -C "${TGT_REPO_DIR}" -xvf -
