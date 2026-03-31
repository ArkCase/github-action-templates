#!/bin/bash
. "${GITHUB_ACTION_FILE}/common.sh"

[ -f "${ENV_FILE}" ] && rm -f "${ENV_FILE}"
