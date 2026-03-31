#!/bin/bash
. "${GITHUB_ACTION_FILE}/common.sh"

export RE_FULL_REVISION="^((0|[1-9][0-9]*)([.][0-9]+)*)(-([a-zA-Z0-9-]+([.][a-zA-Z0-9-]+)*))?([+]([a-zA-Z0-9-]+))?$"

# Check to see the project's visibility
# TODO: CHECK THE DOCKERFILE FOR A REQUEST (ARG) TO KEEP THE BUILD PRIVATE
export PRIVATE="$(gh repo view --json isPrivate --jq .isPrivate)"
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

echo "export VISIBILITY=${VISIBILITY@Q}" | to_env
echo "VISIBILITY=${VISIBILITY@Q}"

echo "export FIPS=${FIPS@Q}" | to_env
echo "FIPS=${FIPS@Q}"

# Split into an array of parts, making sure that double slashes, if present, are condensed into one
# Also remove leading and trailing slashes, for safety. Also, fold it to lowercase
readarray -d / -t PARTS < <(echo -n "${GITHUB_REPOSITORY,,}" | sed -e "s;^/*;;g" -e "s;/*$;;g" -e "s;/\+;/;g")

# So at this point we know that PARTS[0] is the product suite (ArkCase, for instance), and PARTS[1] is the
# repository name (i.e. ark_something-or-other)
# Change out underscores for dashes
export PRODUCT_SUITE="${PARTS[0]//_/-}"
export IMAGE_NAME="${PARTS[1]//_/-}"

# Also, to support more product suites in the future...
case "${PRODUCT_SUITE}" in
	"arkcase" ) IMAGE_NAME="$(echo -n "${IMAGE_NAME}" | sed -e "s;^ark-;;g")" ;;
esac

echo "export PRODUCT_SUITE=${PRODUCT_SUITE@Q}" | to_env
echo "PRODUCT_SUITE=${PRODUCT_SUITE@Q}"

[ -n "${FIPS}" ] && IMAGE_NAME+="${FIPS}"
echo "export IMAGE_NAME=${IMAGE_NAME@Q}" | to_env
echo "IMAGE_NAME=${IMAGE_NAME@Q}"

export IMAGE_URI="${PRODUCT_SUITE}/${IMAGE_NAME}"
echo "export IMAGE_URI=${IMAGE_URI@Q}" | to_env
echo "IMAGE_URI=${IMAGE_URI@Q}"

# Make sure it's defined if it isn't already
REVISION="${PARAM_REVISION}"
PORTAL_VER="${PARAM_PORTAL}"
PUBLISH_MAJOR="${PARAM_PUBLISH_MAJOR}"
PUBLISH_MINOR="${PARAM_PUBLISH_MINOR}"
if [ -z "${REVISION}" ] || [ -z "${PORTAL_VER}" ] ; then
	# Parse out the tag, handle the case when it's not there
	readarray -t NEW_VERSIONS < <(
		set -eo pipefail

		# Parsing out the version from the "VER" argument can be tricky if it's computed from others
		# values or arguments, so let's try it with some sneaky trickery.

		# We have to resort to Perl's evil black magic b/c we have to cover the edge case of
		# line continuations - we have to collapse those, first... then we can find the ARG clauses,
		# and finally convert them all into bash "export" clauses ... which we then consume (this is
		# why redefinition is an issue, above). We use a PREFIX to avoid name clashes with read-only
		# BASH variables which can cause the task to fail, and we use special SED strings to add the
		# prefix as necessary for variable expansion among the arguments themselves
		export PREFIX="____DOCKER_ARG____"

		# It's OK to define these here ... if they get overridden below, we're happy about it.
		# Otherwise, we fall back to these values to avoid failing the parse.
		eval export "${PREFIX}PRIVATE_REGISTRY=${ECR_REGISTRY_PRIVATE@Q}"
		eval export "${PREFIX}PUBLIC_REGISTRY=${ECR_REGISTRY_PUBLIC@Q}"
		eval export "${PREFIX}BASE_REGISTRY=${ECR_REGISTRY_PRIVATE@Q}"

		source <(
			perl -pe "s/\\\s*$//" Dockerfile | \
				grep -E '^\s*ARG\s+[^=]+=' | \
				sed -e "s;\${;\$\{${PREFIX};g" \
					-e "s;\$\([^{]\);\$${PREFIX}\1;g" | \
				sed -e "s;^\s*ARG\s;export ${PREFIX};g"
		)

		for R in "VER" "PORTAL_VER" "PUBLISH_MAJOR" "PUBLISH_MINOR" ; do
			[ -z "${PREFIX}" ] || R="${PREFIX}${R}"
			# This checks for each variable and outputs its
			# value if present, or an empty string if absent
			[ -v "${R}" ] && echo "${!R}" || echo ""
		done
		exit 0
	)
	RC=${?}

	if [ ${RC} -ne 0 ] ; then
		echo "Failed to compute the build version from the Dockerfile (rc=${RC})"
		exit ${RC}
	fi

	# We only override the revision if it wasn't provided as a parameter
	if [ -z "${REVISION}" ] ; then
		if [ -z "${NEW_VERSIONS[0]}" ] ; then
			echo "Failed to compute a build revision from the Dockerfile"
			exit 1
		fi
		REVISION="${NEW_VERSIONS[0]}"
	fi

	# We only override the FOIA Portal version if it wasn't provided as a parameter
	[ -z "${PORTAL_VER}" ] && PORTAL_VER="${NEW_VERSIONS[1]}"

	# These two will allow us to produce tags using only the major version
	# of the container, or the major-minor combo. This in turn allows
	# references to the container based on this, which allows us to update
	# software versions without requiring everyone to keep up perfectly
	[ -z "${PUBLISH_MAJOR}" ] && PUBLISH_MAJOR="${NEW_VERSIONS[2]:-false}"
	[ -z "${PUBLISH_MINOR}" ] && PUBLISH_MINOR="${NEW_VERSIONS[3]:-false}"

	echo "Computed REVISION=${REVISION}"
	echo "Computed PORTAL_VER=${PORTAL_VER}"
	echo "Computed PUBLISH_MAJOR=${PUBLISH_MAJOR}"
	echo "Computed PUBLISH_MINOR=${PUBLISH_MINOR}"
fi
[ "${PUBLISH_MAJOR,,}" == "true" ] && PUBLISH_MAJOR="true" || PUBLISH_MAJOR="false"
[ "${PUBLISH_MINOR,,}" == "true" ] && PUBLISH_MINOR="true" || PUBLISH_MINOR="false"

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
if [[ ! "${REVISION}" =~ ${RE_FULL_REVISION} ]] ; then
	echo "Revision number is not valid: [${REVISION}] ( /${RE_FULL_REVISION}/ )"
	exit 1
fi

BASE_NUMBER="${BASH_REMATCH[1]}"
PRERELEASE="${BASH_REMATCH[5]}"
METADATA="${BASH_REMATCH[8]}"

# If the pre-release info is a "SNAPSHOT", make sure it's used properly
REVISION_SNAPSHOT="false"
if [[ "${PRERELEASE}" =~ SNAPSHOT ]] ; then
	if [[ "${PRERELEASE}" =~ (^|[^a-zA-Z0-9_])SNAPSHOT ]] ; then
		REVISION_SNAPSHOT="true"
	else
		echo "Illegal use of the word 'SNAPSHOT' as [${PRERELASE}] - must be the last word: [${REVISION}]"
		exit 1
	fi
fi

# Do the same validation, but for the FOIA Portal version
if [ -n "${PORTAL_VER}" ] ; then
	if [[ ! "${PORTAL_VER}" =~ ${RE_FULL_REVISION} ]] ; then
		echo "The FOIA Portal version is not valid: [${PORTAL_VER}]"
		exit 1
	fi

	PORTAL_BASE_NUMBER="${BASH_REMATCH[1]}"
	PORTAL_PRERELEASE="${BASH_REMATCH[5]}"
	PORTAL_METADATA="${BASH_REMATCH[8]}"

	# If the pre-release info is a "SNAPSHOT", make sure it's used properly
	PORTAL_SNAPSHOT="false"
	if [[ "${PORTAL_PRERELEASE}" =~ SNAPSHOT ]] ; then
		if [[ "${PORTAL_PRERELEASE}" =~ (^|[^a-zA-Z0-9_])SNAPSHOT ]] ; then
			PORTAL_SNAPSHOT="true"
		else
			echo "Illegal use of the word 'SNAPSHOT' as [${PRERELASE}] - must be the last word: [${PORTAL_VER}]"
			exit 1
		fi
	fi

	# Make sure that the quality level of the ArkCase build is
	# equal to or higher than the quality level for the inteded
	# revision (i.e. don't let SNAPSHOT builds be used as the basis
	# for production builds)
	if "${REVISION_SNAPSHOT}" ; then
		REVISION_QUALITY="0"
	elif [ -n "${PRERELEASE}" ] ; then
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

	if [ ${REVISION_QUALITY} -gt ${PORTAL_QUALITY} ] ; then
		echo "The target revision quality (${REVISION_QUALITY}) is higher than the Portal component quality (${PORTAL_QUALITY}), and this is not allowed"
		exit 1
	fi
fi

# Assume the default is "devel", until proven otherwise
export ENVIRONMENT="devel"
export PREFIX="devel-"
# This makes it easier to add special branch handlers later on
case "${GITHUB_REF}" in
	"refs/heads/main" | "refs/heads/legacy" | "refs/tags/release"/* ) ENVIRONMENT="stable" ; PREFIX="" ;;
esac
echo "export ENVIRONMENT=${ENVIRONMENT@Q}" | to_env
echo "ENVIRONMENT=${ENVIRONMENT@Q}"

echo "export REVISION_PREFIX=${PREFIX@Q}" | to_env
echo "REVISION_PREFIX=${PREFIX@Q}"

echo "export REVISION=${REVISION@Q}" | to_env
echo "export REVISION_BASE_NUMBER=${BASE_NUMBER@Q}" | to_env
echo "export REVISION_PRERELEASE=${PRERELEASE@Q}" | to_env
echo "export REVISION_METADATA=${METADATA@Q}" | to_env
echo "export REVISION_SNAPSHOT=${REVISION_SNAPSHOT@Q}" | to_env
echo "REVISION=${REVISION@Q}"
echo "REVISION_BASE_NUMBER=${BASE_NUMBER@Q}"
echo "REVISION_PRERELEASE=${PRERELEASE@Q}"
echo "REVISION_METADATA=${METADATA@Q}"
echo "REVISION_SNAPSHOT=${REVISION_SNAPSHOT@Q}"

if [ -n "${PORTAL_VER}" ] ; then
	echo "export PORTAL_VER=${PORTAL_VER@Q}" | to_env
	echo "export PORTAL_BASE_NUMBER=${PORTAL_BASE_NUMBER@Q}" | to_env
	echo "export PORTAL_PRERELEASE=${PORTAL_PRERELEASE@Q}" | to_env
	echo "export PORTAL_METADATA=${PORTAL_METADATA@Q}" | to_env
	echo "export PORTAL_SNAPSHOT=${PORTAL_SNAPSHOT@Q}" | to_env
	echo "PORTAL_VER=${PORTAL_VER@Q}"
	echo "PORTAL_BASE_NUMBER=${PORTAL_BASE_NUMBER@Q}"
	echo "PORTAL_PRERELEASE=${PORTAL_PRERELEASE@Q}"
	echo "PORTAL_METADATA=${PORTAL_METADATA@Q}"
	echo "PORTAL_SNAPSHOT=${PORTAL_SNAPSHOT@Q}"
fi

echo "export PUBLISH_MAJOR=${PUBLISH_MAJOR@Q}" | to_env
echo "PUBLISH_MAJOR=${PUBLISH_MAJOR@Q}"
echo "export PUBLISH_MINOR=${PUBLISH_MINOR@Q}" | to_env
echo "PUBLISH_MINOR=${PUBLISH_MINOR@Q}"

export LEGACY="false"
[[ "${GITHUB_REF_NAME}" =~ -legacy$ ]] && LEGACY="true"
echo "export LEGACY=${LEGACY@Q}" | to_env
echo "LEGACY=${LEGACY@Q}"

# We only push to public if this is a public repository,
# AND this build is not a pre-release build
export PUSH_TO_PUBLIC="false"
[ "${ENVIRONMENT}" == "stable" ] && [ "${VISIBILITY}" == "public" ] && [ -z "${PRERELEASE}" ] && PUSH_TO_PUBLIC="true"
echo "export PUSH_TO_PUBLIC=${PUSH_TO_PUBLIC@Q}" | to_env
echo "PUSH_TO_PUBLIC=${PUSH_TO_PUBLIC@Q}"
