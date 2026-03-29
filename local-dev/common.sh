#!/bin/bash

# ECR_AWS_REGION: ${{ secrets.ECR_AWS_REGION }}
# ECR_AWS_ORG_ID: ${{ secrets.ECR_AWS_ORG_ID }}
# GH_TOKEN: ${{ github.token }}

export SCANNER_IMAGE="arkcase/security-scanner:20251120.01"

# Enable/disable STIG Compliance Scans
# SCAN_COMP: ${{ inputs.compliance-scan }}
# SCAN_COMP_REQUIRED: ${{ inputs.compliance-required }}

# Enable/disable Vulnerability Scans
# SCAN_VULN: ${{ inputs.vulnerabilities-scan }}
# SCAN_VULN_REQUIRED: ${{ inputs.vulnerabilities-required }}

# MAXIMIZE_BUILD_SPACE: ${{ inputs.maximize-build-space }}

export DEVEL_KEEP_DAYS="30"
export SNAPSHOT_KEEP_DAYS="30"
export RE_FULL_REVISION="^((0|[1-9][0-9]*)([.][0-9]+)*)(-([a-zA-Z0-9-]+([.][a-zA-Z0-9-]+)*))?([+]([a-zA-Z0-9-]+))?$"

#
# If not checked out to a branch, what do these look like?
#
[ -n "${GITHUB_REF:-}" ] || export GITHUB_REF="$(git rev-parse --symbolic-full-name HEAD)"
[ -n "${GITHUB_REF_NAME:-}" ] || export GITHUB_REF_NAME="$(git rev-parse --abbrev-ref HEAD)"
if [ -z "${GITHUB_REF_TYPE:-}" ] ; then
	case "${GITHUB_REF}" in
		refs/heads/* ) GITHUB_REF_TYPE="branch" ;;
		* ) GITHUB_REF_TYPE="tag" ;;
	esac
fi
if [ -z "${GITHUB_REPOSITORY:-}" ] ; then
	# Compute the values!
	GITHUB_REPOSITORY="$(git remote get-url origin)"
	[[ "${GITHUB_REPOSITORY}" =~ ^git@[^:]+:([^/]+)/([^/]+)([.]git)?$ ]] \
		|| [[ "${GITHUB_REPOSITORY}" =~ ^https://[^/]+/([^/]+)/([^/]+)([.]git)?$ ]] \
		|| fail "Invalid GitHub URL [${GITHUB_REPOSITORY}]"

	# Harvest the parsed results
	export GITHUB_OWNER="${BASH_REMATCH[1]}"
	export GITHUB_REPO="${BASH_REMATCH[2]}"
	export GITHUB_REPOSITORY="${GITHUB_OWNER}/${GITHUB_REPO}"
fi
[ -n "${GITHUB_RUN_NUMBER:-}" ] || GITHUB_RUN_NUMBER="$(date -u "+%s")"
[ -n "${GITHUB_SHA:-}" ] || export GITHUB_SHA="$(git rev-parse HEAD)" || GITHUB_SHA="unknown-sha-sum"
[ -n "${GITHUB_WORKSPACE:-}" ] || export GITHUB_WORKSPACE="$(readlink -f .)"

append_to_file()
{
	local FILE="${1}"
	shift

	# No parameters? The data is from stdin!
	if [ ${#} -eq 0 ] ; then
		cat >> "${FILE}" || return ${?}
	else
		# Parameters? That's the data! Spit it out one per line,
		# ignoring empty lines
		for N in "${@}" ; do
			[ -n "${N}" ] || continue
			echo "${N}" >> "${FILE}" || return ${?}
		done
	fi
	return 0
}

github_output()
{
	# If the variable is not set, or is empty, we simply produce nothing
	[ -n "${GITHUB_OUTPUT:-}" ] || return 0
	append_to_file "${GITHUB_OUTPUT}" "${@}"
	return ${?}
}

github_env()
{
	# If the variable is not set, or is empty, we simply produce nothing
	[ -n "${GITHUB_ENV:-}" ] || return 0
	append_to_file "${GITHUB_ENV}" "${@}"
	return ${?}
}

to_env()
{
	local ENV=""
	local WS=""
	[ -n "${GITHUB_WORKSPACE:-}" ] && WS="${GITHUB_WORKSPACE}" || WS="$(readlink -f .)"
	[ -n "${ENVFILE:-}" ] && ENV="${ENVFILE}" || ENV="${WS}/.env"
	append_to_file "${ENV}" "${@}"
	return ${?}
}
