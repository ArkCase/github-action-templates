#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

if [[ ! "${GITHUB_REF}" =~ ^refs/tags/(([^/]+)/([^/]+)/([^/]+))$ ]] ; then
	say "This ref type is not supported for triggering a Chart publication: ${GITHUB_REF}"
	to_env EXIT="true"
	exit 0
fi

# The name of the chart (relative to the chart directory, no "/" allowed in the name)
CHART_NAME="${BASH_REMATCH[2]}"

# The type of release: test/release
RELEASE_TYPE="${BASH_REMATCH[3]}"

# The version being released
VERSION="${BASH_REMATCH[4]}"

VERSION_RE='^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)([.](0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?([+]([0-9a-zA-Z-]+([.][0-9a-zA-Z-]+)*))?$'
[[ "${VERSION}" =~ ${VERSION_RE} ]] || fail "Invalid version number [${VERSION}] - must match SemVer rules"

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"
PRE_RELEASE="${BASH_REMATCH[5]}"
BUILD_METADATA="${BASH_REMATCH[10]}"

if [ -n "${PRE_RELEASE}" ] ; then
	VERSION_TYPE="test"
else
	VERSION_TYPE="release"
fi

[ "${VERSION_TYPE}" == "${RELEASE_TYPE}" ] || fail "The version number ${VERSION} may only be used for ${VERSION_TYPE} releases, not for ${RELEASE_TYPE} releases."

for VAR in CHART_DIR PUBLIC_DIR DOC_DIR ; do
	if [ -v "${VAR}" ] && [ -n "${!VAR}" ] ; then
		# Validate that the path isn't absolute, and doesn't have ".." elements
		case "${!VAR}" in
			/* ) fail "The ${VAR} value may not be an absolute path" ;;
			.. | ../* | */.. | */../* ) fail "The ${VAR} value may not contain '..' elements" ;;
			* ) ;;
		esac
	else
		declare -x "${VAR}=."
	fi
done

# Everything looks good ... four more variables to compute
CHART_SRC_DIR="${SRC_REPO_DIR}/${CHART_DIR}"
CHART_TGT_DIR="${TGT_REPO_DIR}/${PUBLIC_DIR}"
CHART_TGT_FILE="${CHART_NAME}-${VERSION}.tgz"
DOC_SRC_DIR="${SRC_REPO_DIR}/${DOC_DIR}"

# Make sure no symlinks take any of these outside of the sources checkout.
# The target paths are checked once the GH Pages branch is checked out.
ensure_inside "${SRC_REPO_DIR}" "${CHART_SRC_DIR}" "chart directory"
ensure_inside "${SRC_REPO_DIR}" "${CHART_SRC_DIR}/${CHART_NAME}" "chart [${CHART_NAME}]"
ensure_inside "${SRC_REPO_DIR}" "${DOC_SRC_DIR}" "documentation directory"

# Export all the computed variables in their exact current values
ok "All parameters appear to be valid"
for VAR in CHART_NAME RELEASE_TYPE VERSION MAJOR MINOR PATCH PRE_RELEASE BUILD_METADATA CHART_SRC_DIR CHART_TGT_DIR CHART_TGT_FILE DOC_SRC_DIR ; do
	to_env "${VAR}"
	say "${VAR}=${!VAR}"
done
