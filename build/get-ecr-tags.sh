#!/bin/bash

# So we can test it *REPEATEDLY*
[ -v GITHUB_ACTION_PATH ] || export GITHUB_ACTION_PATH="$(dirname "$(readlink -f "${0}")")"

. "${GITHUB_ACTION_PATH}/common.sh"

usage()
{
	echo -e "usage: ${BASH_ARGV0:-${BASH_SOURCE:-${0}}} (ecr | ecr-public) name-or-uri"
	exit 1
}

[ ${#} -eq 2 ] || usage

ECR="${1}"
QUERY="${2}"

CMD=( aws "${ECR}" describe-images --repository-name "${QUERY}" )
DATA="$("${CMD[@]}" 2>&1)" || fail "Failed to fetch the image tag list for [${QUERY}] from [${ECR}] (rc=${?}): ${DATA}"
jq -r '.imageDetails[] | select(has("imageTags")) | .imageTags[]' <<< "${DATA}" 2>&1 || fail "Failed to parse the image tag list for [${QUERY}] from [${ECR}] (rc=${?})"
exit 0
