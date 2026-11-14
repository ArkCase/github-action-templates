#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

# So we can easily identify what's what and not mix things up
to_env SRC_REPO_DIR="sources" TGT_REPO_DIR="pages"

# All subsequent steps are skipped once this is set to "true"
to_env EXIT="false"

# Initial state: a failed run deletes the tag that triggered it
to_env DELETE_TAG="true"
