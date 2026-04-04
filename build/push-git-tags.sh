#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

is_local_dev && CMD="running" || CMD="exec"

"${CMD}" git push --force --tags
