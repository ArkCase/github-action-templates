#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

#
# Define the context-appropriate default value for KEEP_DOCKER_CACHE
#
# If we're in local development and it's not expressly set, we assume
# that we want to keep the Docker cache.  Otherwise, for non-local
# development, we assume that we DON'T want to keep the Docker cache.
#
# If the value is expressly set to either "true" or "false", we keep it
# as provided and carry on with the build.
is_local_dev && DEFAULT_KEEP_DOCKER_CACHE="true" || DEFAULT_KEEP_DOCKER_CACHE="false"

#
# Sanitize the value for KEEP_DOCKER_CACHE
#
[ -v KEEP_DOCKER_CACHE ] || KEEP_DOCKER_CACHE=""
KEEP_DOCKER_CACHE="${KEEP_DOCKER_CACHE,,}"
case "${KEEP_DOCKER_CACHE}" in
	true | false ) ;;
	* ) KEEP_DOCKER_CACHE="${DEFAULT_KEEP_DOCKER_CACHE}" ;;
esac
to_env KEEP_DOCKER_CACHE

#
# This is useful for validating revision numbers
#
export RE_FULL_REVISION="^((0|[1-9][0-9]*)([.][0-9]+)*)(-([a-zA-Z0-9-]+([.][a-zA-Z0-9-]+)*))?([+]([a-zA-Z0-9-]+))?$"

#
# Check to see the project's visibility
#
# TODO: CHECK THE DOCKERFILE FOR A REQUEST (ARG) TO KEEP THE BUILD PRIVATE?
PRIVATE="$(gh repo view --json isPrivate --jq .isPrivate)" || PRIVATE="true"
case "${PRIVATE,,}" in
	false | true ) PRIVATE="${PRIVATE,,}" ;;
	* ) PRIVATE="false" ;;
esac
export VISIBILITY="private"
export FIPS=""

#
# The fips-enabled stuff is kept private
#
if [ "${VARIANT}" == "fips" ] ; then
	FIPS="-fips"
	PRIVATE="true"
fi
"${PRIVATE}" || VISIBILITY="public"

to_env VISIBILITY FIPS

#
# Split into an array of parts, making sure that double slashes, if present, are condensed into one
# Also remove leading and trailing slashes, for safety. Also, fold it to lowercase
#
readarray -d / -t PARTS < <(echo -n "${GITHUB_REPOSITORY,,}" | sed -e "s;^/*;;g" -e "s;/*$;;g" -e "s;/\+;/;g")

#
# So at this point we know that PARTS[0] is the product suite
# (ArkCase, for instance), and PARTS[1] is the repository name
# (i.e. ark_something-or-other). Change out underscores for dashes.
#
export PRODUCT_SUITE="${PARTS[0]//_/-}"
export IMAGE_NAME="${PARTS[1]//_/-}"

# Also, to support more product suites in the future...
case "${PRODUCT_SUITE}" in
	"arkcase" ) IMAGE_NAME="$(echo -n "${IMAGE_NAME}" | sed -e "s;^ark-;;g")" ;;
esac
[ -n "${FIPS}" ] && IMAGE_NAME+="${FIPS}"
export IMAGE_URI="${PRODUCT_SUITE}/${IMAGE_NAME}"

to_env PRODUCT_SUITE IMAGE_NAME IMAGE_URI

#
# Override, if necessary/appropriate ...
#
[ -z "${PRIVATE_REGISTRY:-}" ] && [ -n "${ECR_REGISTRY_PRIVATE:-}" ] && to_env PRIVATE_REGISTRY="${ECR_REGISTRY_PRIVATE}"
[ -z "${PUBLIC_REGISTRY:-}" ] && [ -n "${ECR_REGISTRY_PUBLIC:-}" ] && to_env PUBLIC_REGISTRY="${ECR_REGISTRY_PUBLIC}"

[ -n "${PRIVATE_REGISTRY}" ] && [ -n "${PUBLIC_REGISTRY}" ] || fail "The registry values were not computed properly: PRIVATE=${PRIVATE_REGISTRY@Q} PUBLIC=${PUBLIC_REGISTRY@Q}"

#
# Make sure it's defined if it isn't already
#
REVISION="${PARAM_REVISION}"
PORTAL_VER="${PARAM_PORTAL}"
PUBLISH_MAJOR=""
PUBLISH_MINOR=""

#
# TODO: this is in preparation for supporting different
# Dockerfiles based on version/variant (and combo)
#
DOCKERFILE="${GITHUB_WORKSPACE}/Dockerfile"

#
# If we weren't given a REVISION or a PORTAL_VER we want to "parse"
# the Dockerfile and get the default values for any ARG declarations
# since these will give us the default values we should use.
#
if [ -z "${REVISION}" ] || [ -z "${PORTAL_VER}" ] ; then
	# Parse out the tag, handle the case when it's not there
	VARS=( "VER" "PORTAL_VER" "PUBLISH_MAJOR" "PUBLISH_MINOR" )
	RC=0
	DOCKERFILE_ARG_DECLARATIONS="$( "${GITHUB_ACTION_PATH}/read-dockerfile-args.sh" "${VARS[@]}" < "${DOCKERFILE}" 2>&1)" || RC=${?}
	if [ ${RC} -ne 0 ] ; then
		echo "Failed to compute the Dockerfile argument declarations (rc=${RC}): ${DOCKERFILE_ARG_DECLARATIONS}"
		exit ${RC}
	fi

	# Declare the variables for consumption
	while read DECLARATION ; do
		[ -n "${DECLARATION}" ] && declare -xg "DOCKERFILE_${DECLARATION}"
	done <<< "${DOCKERFILE_ARG_DECLARATIONS}"

	# We only override the revision if it wasn't provided as a parameter
	if [ -z "${REVISION}" ] ; then
		[ -n "${DOCKERFILE_VER}" ] || fail "Failed to compute a build revision from the Dockerfile"
		REVISION="${DOCKERFILE_VER}"
	fi

	# We only override the FOIA Portal version if it wasn't provided as a parameter
	[ -z "${PORTAL_VER}" ] && PORTAL_VER="${DOCKERFILE_PORTAL_VER}"

	# These two will allow us to produce tags using only the major version
	# of the container, or the major-minor combo. This in turn allows
	# references to the container based on this, which allows us to update
	# software versions without requiring everyone to keep up perfectly
	[ -z "${PUBLISH_MAJOR}" ] && PUBLISH_MAJOR="${DOCKERFILE_PUBLISH_MAJOR:-false}"
	[ -z "${PUBLISH_MINOR}" ] && PUBLISH_MINOR="${DOCKERFILE_PUBLISH_MINOR:-false}"

	echo "Computed REVISION=${REVISION}"
	echo "Computed PORTAL_VER=${PORTAL_VER}"
	echo "Computed PUBLISH_MAJOR=${PUBLISH_MAJOR}"
	echo "Computed PUBLISH_MINOR=${PUBLISH_MINOR}"
fi

#
# Make sure these two have a valid boolean value
#
[ "${PUBLISH_MAJOR,,}" == "true" ] && PUBLISH_MAJOR="true" || PUBLISH_MAJOR="false"
[ "${PUBLISH_MINOR,,}" == "true" ] && PUBLISH_MINOR="true" || PUBLISH_MINOR="false"

to_env PUBLISH_MAJOR PUBLISH_MINOR

#
# Parse for vailidity ... we'll examine it more closely later
#
# This is inspired by, but not strictly adhering to, semantic versioning. It deviates
# in the following ways:
#
#	 * Leading zeros are allowed on all but the first component of the version number
#	 * More than 3 dot-separated components are allowed on the version number
#	 * Version numbers with only 2 components are allowed
#
# Otherwise, the rest is the same: same rules for pre-release tags and metadata tags.
#
[[ "${REVISION}" =~ ${RE_FULL_REVISION} ]] || fail "Revision number is not valid: [${REVISION}] ( /${RE_FULL_REVISION}/ )"

REVISION_BASE_NUMBER="${BASH_REMATCH[1]}"
REVISION_PRERELEASE="${BASH_REMATCH[5]}"
REVISION_METADATA="${BASH_REMATCH[8]}"

#
# If the pre-release info is a "SNAPSHOT", make sure it's used properly
#
REVISION_SNAPSHOT="false"
if [[ "${REVISION_PRERELEASE}" =~ SNAPSHOT ]] ; then
	[[ "${REVISION_PRERELEASE}" =~ (^|[^a-zA-Z0-9_])SNAPSHOT ]] || fail "Illegal use of the word 'SNAPSHOT' as [${PRERELASE}] - must be the last word: [${REVISION}]"
	REVISION_SNAPSHOT="true"
fi

#
# Do the same validation, but for the FOIA Portal version
#
if [ -n "${PORTAL_VER}" ] ; then
	[[ "${PORTAL_VER}" =~ ${RE_FULL_REVISION} ]] || fail "The FOIA Portal version is not valid: [${PORTAL_VER}]"

	PORTAL_BASE_NUMBER="${BASH_REMATCH[1]}"
	PORTAL_PRERELEASE="${BASH_REMATCH[5]}"
	PORTAL_METADATA="${BASH_REMATCH[8]}"

	# If the pre-release info is a "SNAPSHOT", make sure it's used properly
	PORTAL_SNAPSHOT="false"
	if [[ "${PORTAL_PRERELEASE}" =~ SNAPSHOT ]] ; then
		[[ "${PORTAL_PRERELEASE}" =~ (^|[^a-zA-Z0-9_])SNAPSHOT ]] || fail "Illegal use of the word 'SNAPSHOT' as [${PRERELASE}] - must be the last word: [${PORTAL_VER}]"
		PORTAL_SNAPSHOT="true"
	fi

	# Make sure that the quality level of the ArkCase build is
	# equal to or higher than the quality level for the inteded
	# revision (i.e. don't let SNAPSHOT builds be used as the basis
	# for production builds)
	if "${REVISION_SNAPSHOT}" ; then
		REVISION_QUALITY="0"
	elif [ -n "${REVISION_PRERELEASE}" ] ; then
		REVISION_QUALITY="1"
	else
		REVISION_QUALITY="2"
	fi
	echo "REVISION_QUALITY=${REVISION_QUALITY}"

	if "${PORTAL_SNAPSHOT}" ; then
		PORTAL_QUALITY="0"
	elif [ -n "${PORTAL_PRERELEASE}" ] ; then
		PORTAL_QUALITY="1"
	else
		PORTAL_QUALITY="2"
	fi
	echo "PORTAL_QUALITY=${PORTAL_QUALITY}"

	[ ${REVISION_QUALITY} -le ${PORTAL_QUALITY} ] || fail "The target revision quality (${REVISION_QUALITY}) is higher than the Portal component quality (${PORTAL_QUALITY}), and this is not allowed"
fi

# Assume the default is "devel", until proven otherwise
export ENVIRONMENT="devel"
export REVISION_PREFIX="devel-"
# This makes it easier to add special branch handlers later on
if ! is_local_dev ; then
	case "${GITHUB_REF}" in
		"refs/heads/main" | "refs/tags/release"/* ) ENVIRONMENT="stable" ; REVISION_PREFIX="" ;;
	esac
fi
to_env ENVIRONMENT REVISION_PREFIX

to_env \
	REVISION \
	REVISION_BASE_NUMBER \
	REVISION_PRERELEASE \
	REVISION_METADATA \
	REVISION_SNAPSHOT

if [ -n "${PORTAL_VER}" ] ; then
	to_env \
		PORTAL_VER \
		PORTAL_BASE_NUMBER \
		PORTAL_PRERELEASE \
		PORTAL_METADATA \
		PORTAL_SNAPSHOT
fi


# We only push to public if this is a public repository,
# AND this build is not a pre-release build
export PUSH_TO_PUBLIC="false"
[ "${ENVIRONMENT}" == "stable" ] && [ "${VISIBILITY}" == "public" ] && [ -z "${REVISION_PRERELEASE}" ] && PUSH_TO_PUBLIC="true"

to_env PUSH_TO_PUBLIC
