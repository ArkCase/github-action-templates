#!/bin/bash

set -euo pipefail
. "${GITHUB_ACTION_PATH}/common.sh"

usage()
{
	echo -e "usage: ${BASH_ARGV0:-${BASH_SOURCE:-${0}}} registry repository"
	exit 1
}

[ ${#} -eq 2 ] || usage

REG="${1}"
REPO="${2}"

get_docker_auth()
{
	local REG="${1}"
	local CONF="${HOME}/.docker/config.json"
	[ -f "${CONF}" ] || return 0
	local AUTH=""
	AUTH="$(jq -r --arg REG "${REG}" '.auths[$REG].auth // ""' < "${CONF}")" || return 1
	[ -n "${AUTH}" ] || return 0
	base64 -d <<< "${AUTH}" || return 1
	return 0
}

AUTH="$(get_docker_auth "${REG}" 2>&1)" && [ -n "${AUTH}" ] && AUTH=(--user "${AUTH}") || AUTH=()
CMD=( curl -fsSL "${AUTH[@]}" "https://${REG}/v2/${REPO}/tags/list" )
DATA="$("${CMD[@]}" 2>&1)" || fail "Failed to fetch the image tag list for [${REPO}] from [${REG}] (rc=${?}): ${DATA}"
jq -r '.tags[]' <<< "${DATA}" 2>&1 || fail "Failed to parse the image tag list for [${REPO}] from [${REG}] (rc=${?})"
exit 0
