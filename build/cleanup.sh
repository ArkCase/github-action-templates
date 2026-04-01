#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

[ -f "${ENV_FILE}" ] && rm -f "${ENV_FILE}"
