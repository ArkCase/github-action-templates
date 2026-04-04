#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

WORK_DIR="$(readlink -f "${GITHUB_WORKSPACE:-.}")"

# Set any build arguments with private values
BUILD_ARGS=()
BUILD_ARGS+=(--build-arg "FIPS=${FIPS}")

# Always use the base version for this ...
BUILD_ARGS+=(--build-arg "VER=${REVISION}")
[ -n "${PORTAL_VER:-}" ] && BUILD_ARGS+=(--build-arg "PORTAL_VER=${PORTAL_VER}")

# Select the base registries
BUILD_ARGS+=(--build-arg "PRIVATE_REGISTRY=${PRIVATE_REGISTRY}")
BUILD_ARGS+=(--build-arg "PUBLIC_REGISTRY=${PUBLIC_REGISTRY}")
BUILD_ARGS+=(--build-arg "BASE_VER_PFX=${REVISION_PREFIX}")

# Select which one is the BASE registry, based on whether this
# container is to be pushed to public or not
BASE_REGISTRY="${PRIVATE_REGISTRY}"
"${PUSH_TO_PUBLIC}" && BASE_REGISTRY="${PUBLIC_REGISTRY}"
BUILD_ARGS+=(--build-arg "BASE_REGISTRY=${BASE_REGISTRY}")

# Apply the predefined BUILD_ARG_* arguments
for VAR in "${!BUILD_ARG_@}" ; do
	[[ "${VAR}" =~ ^BUILD_ARG_(.+)$ ]] || continue
	ARG="${BASH_REMATCH[1]}"
	BUILD_ARGS+=(--build-arg "${ARG}=${!VAR}")
done

SECRETS_DIR="$(mktemp -d --tmpdir="${WORK_DIR}" ".secrets-XXXXXX.tmp")"
mkdir -p "${SECRETS_DIR}"

# Next, add all the stuff S3 will need to pull crap
AWS_PROFILE="armedia-docker-build"
AWS_CONF="${SECRETS_DIR}/aws_conf"
(
	echo "[profile ${AWS_PROFILE}]"
	echo "region=${ECR_AWS_REGION}"
) &> "${AWS_CONF}"
BUILD_ARGS+=(--secret id=aws_conf,src="${AWS_CONF}")

AWS_AUTH="${SECRETS_DIR}/aws_auth"
(
	echo "[${AWS_PROFILE}]"
	echo "aws_access_key_id=${ECR_AWS_ACCESS_KEY}"
	echo "aws_secret_access_key=${ECR_AWS_SECRET_ACCESS_KEY}"
) |& sort &> "${AWS_AUTH}"
BUILD_ARGS+=(--secret id=aws_auth,src="${AWS_AUTH}")

# Add the Curl authentication deetz
CURL_SECRETS="${SECRETS_DIR}/curl"
for VAR in "${!CURL_@}" ; do
	echo "export ${VAR}=${!VAR@Q}"
done |& sort &> "${CURL_SECRETS}"
BUILD_ARGS+=(--secret id=curl_auth,src="${CURL_SECRETS}")
sha256sum "${CURL_SECRETS}"

# Add the Maven authentication deetz
MVN_GET_SECRETS="${SECRETS_DIR}/mvn-get"
for VAR in "${!MVN_GET_@}" ; do
	echo "export ${VAR}=${!VAR@Q}"
done |& sort &> "${MVN_GET_SECRETS}"
BUILD_ARGS+=(--secret id=mvn_get_auth,src="${MVN_GET_SECRETS}")
sha256sum "${MVN_GET_SECRETS}"

# Final details for more complete information
BUILD_ARGS+=(--label "GIT_REPOSITORY=${GITHUB_REPOSITORY}")
BUILD_ARGS+=(--label "GIT_REF=${GITHUB_REF_NAME}")
BUILD_ARGS+=(--label "GIT_REF_TYPE=${GITHUB_REF_TYPE}")
BUILD_ARGS+=(--label "GIT_COMMIT=${GITHUB_SHA}")
BUILD_ARGS+=(--label "GIT_BUILD_NUMBER=${GITHUB_RUN_NUMBER}")
BUILD_ARGS+=(--label "GIT_BUILD_TIMESTAMP=${TIMESTAMP}")
is_local_dev && BUILD_ARGS+=(--label "LOCAL_DEV=true")

COMMIT_COUNT="$(git rev-list --count HEAD)"
BUILD_ARGS+=(--label "GIT_COMMIT_COUNT=${COMMIT_COUNT}")

#
# These are the revisions that will be built
#     ${REVISION_BASE_NUMBER}${REVISION_PRERELEASE}[_${REVISION_METADATA}]
#     ${REVISION_BASE_NUMBER}${REVISION_PRERELEASE}_b${GITHUB_RUN_NUMBER}[-${REVISION_METADATA}]
#
# The ordering of components is important for detemining who gets
# the "latest" (or devel-latest) tag.
#
# The significance of components when comparing is:
#
#     * REVISION_BASE_NUMBER
#     * GITHUB_RUN_NUMBER
#     * REVISION_METADATA
#
# We don't take into account the pre-release stuff b/c those will never get tagged as
# "latest" because they're *pre-release* artifacts (this includes SNAPSHOT artifacts).
#
# This also applies to "devel" artifacts, since these aren't inteded to be public. However,
# we do have a "devel-latest" which can be useful.
#

# If we have a pre-release tag, pre-pend a dash
[ -n "${REVISION_PRERELEASE}" ] && REVISION_PRERELEASE="-${REVISION_PRERELEASE}"

MAJOR_REVISION=""
MINOR_REVISION=""
VERSION_PARTS=( ${REVISION_BASE_NUMBER//./ } )
[ "${PUBLISH_MAJOR}" == "true" ] && [ ${#VERSION_PARTS[@]} -ge 2 ] && MAJOR_REVISION="${VERSION_PARTS[0]}"
[ "${PUBLISH_MINOR}" == "true" ] && [ ${#VERSION_PARTS[@]} -ge 3 ] && MINOR_REVISION="${VERSION_PARTS[0]}.${VERSION_PARTS[1]}"

# This will house all the different revisions by which this
# artifact will be known
REVISIONS=()

# NOTE: we use "_" instead of "+" as the revision metadata
# separator here b/c the plus sign is not permitted in Docker tags

# The first metadata must be appended with a leading underscore
REVISION_SUFFIX="${REVISION_PRERELEASE}${REVISION_METADATA:+_}${REVISION_METADATA}"
REVISIONS+=("${REVISION_PREFIX}${REVISION_BASE_NUMBER}${REVISION_SUFFIX}")
[ -n "${MAJOR_REVISION}" ] && REVISIONS+=("${REVISION_PREFIX}${MAJOR_REVISION}${REVISION_SUFFIX}")
[ -n "${MINOR_REVISION}" ] && REVISIONS+=("${REVISION_PREFIX}${MINOR_REVISION}${REVISION_SUFFIX}")

# For the other builds, if there's any metadata, it will need a dash up front from here on
[ -n "${REVISION_METADATA}" ] && REVISION_METADATA="-${REVISION_METADATA}"

# This is the most exact revision, which will be used for "latest" computation
REVISION_SUFFIX="${REVISION_PRERELEASE}_b${GITHUB_RUN_NUMBER}${REVISION_METADATA}"
EXACT_REVISION="${REVISION_PREFIX}${REVISION_BASE_NUMBER}${REVISION_SUFFIX}"
REVISIONS+=("${EXACT_REVISION}")
[ -n "${MAJOR_REVISION}" ] && REVISIONS+=("${REVISION_PREFIX}${MAJOR_REVISION}${REVISION_SUFFIX}")
[ -n "${MINOR_REVISION}" ] && REVISIONS+=("${REVISION_PREFIX}${MINOR_REVISION}${REVISION_SUFFIX}")

TARGETS=()
TARGETS+=("${PRIVATE_REGISTRY}/${IMAGE_URI}")
"${PUSH_TO_PUBLIC}" && TARGETS+=("${PUBLIC_REGISTRY}/${IMAGE_URI}")

# Set the build tags to be built. Make sure to cover
# both targets if applicable
BUILDS=()
for T in "${TARGETS[@]}" ; do
	for R in "${REVISIONS[@]}" ; do
		BUILDS+=("${T}:${R}")
	done
done

# We only compute the need for a "latest" tag if
# this is not a pre-release artifact.
if [ -z "${REVISION_PRERELEASE}" ] ; then
	#
	# Identify if we need to bear the tag of "latest" per the
	# version precedence rules laid out above
	#

	# This is important: the number of dots will help us figure out
	# the regular expressions to use below when seeking out the full
	# version numbers, vs. just the partial ones
	DOTS="$(echo "${REVISION_BASE_NUMBER}" | fgrep -o "." | wc -l)" || true

	# Since we know we won't have any pre-release stuff, we can
	# construct this selector regex to not allow any pre-release
	# information on the tags. We don't really care about metadata
	# since it's the LAST component to be taken into account, and
	# it most likely will never come into play since the timestamp
	# will almost assuredly NEVER coincide.
	RE_MAJOR="(0|[1-9][0-9]*)"
	RE_MINOR="([.][0-9]+)"

	# These will help select the version numbers to examine
	# for the different version scopes
	RE_REVISION_SELECTOR="${RE_MAJOR}${RE_MINOR}{${DOTS},}"
	RE_MAJOR_SELECTOR="${MAJOR_REVISION}${RE_MINOR}{${DOTS},}"
	RE_MINOR_SELECTOR="\Q${MINOR_REVISION}\E"

	# This is to support version numbers with fewer than 3
	# components
	[ ${DOTS} -ge 2 ] && RE_MINOR_SELECTOR+="${RE_MINOR}+"

	# Now let's figure out where this specific build version fits
	# with respect to all the others. This needs to be done twice
	# because the public versions may differ from the private ones
	for ECR in ecr ecr-public ; do
		LABEL=""
		case "${ECR}" in
			ecr )
				LABEL="private"
				QUERY="${IMAGE_URI}"
				REG="${PRIVATE_REGISTRY}"
				;;

			ecr-public )
				"${PUSH_TO_PUBLIC}" || continue
				LABEL="public"
				QUERY="${IMAGE_NAME}"
				REG="${PUBLIC_REGISTRY}"
				;;

			* ) break ;;
		esac

		# Let's get the list of all the revisions, without the extra
		# markers that are actually noise at this specific juncture. We
		# do it like this so we only query the list twice.
		if is_local_dev ; then
			# TODO: get the tags using standard docker registry APIs ... how?!?!
			ALL_REVISIONS=""
		else
			ALL_REVISIONS="$("${GITHUB_ACTION_PATH}/get-ecr-tags.sh" "${ECR}" "${QUERY}")" || ALL_REVISIONS=""
			[ -n "${ALL_REVISIONS}" ] && ALL_REVISIONS="$(
				echo "${ALL_REVISIONS}" | \
				grep -E "^${REVISION_PREFIX}${RE_REVISION_SELECTOR}$" | \
				sed -e "s;^${REVISION_PREFIX};;g" | \
				sort --version-sort --unique --reverse
			)"
		fi

		# We have a possible maximum of 3 "latest" tags to create:
		#
		#    - the "overall" latest version (i.e. *.*.*)
		#      (this one will include the other two because if it's the
		#      overall latest version, it will also be the latest version
		#      for its major-minor group, as well as for its major group)
		IS_LATEST="false"

		#    - the major-minor latest (i.e. A.B.*)
		#      (it's the latest version in its major-minor group, but
		#      not necessarily in its major group. Example: given
		#      the versions 10.2.8, 10.3.1, and 10.4.15, if we try to
		#      add the version 10.3.2 it will be the latest in the
		#      10.3.* group, but NOT the 10.*.* group which will retain
		#      its own latest marker)
		IS_LATEST_MINOR="false"

		#    - the major latest (i.e. A.*.*)
		#      (it's the latest version within its major group. Given
		#      the versions 9.4.5, 9.7.8, and 9.15.2, if we try to
		#      add the version 9.16.0, then it will be the latest in
		#      the 9.*.* group, but NOT in the 9.15.*, 9.7.*, or 9.4.*
		#      groups, which will retain their own latest marker)
		IS_LATEST_MAJOR="false"

		# Ok, now let's see which level(s) of "latest" this version
		# is within this specific scope
		for V in FULL MAJOR MINOR ; do
			LATEST_ADDED="false"
			LATEST_MINOR_ADDED="false"
			LATEST_MAJOR_ADDED="false"

			case "${V}" in

				FULL )
					SELECTOR="${RE_REVISION_SELECTOR}"
					;;

				MINOR )
					# If we're not publishing the major-minor revision, we skip this
					[ -n "${MINOR_REVISION}" ] || continue
					SELECTOR="${RE_MINOR_SELECTOR}"
					;;

				MAJOR )
					# If we're not publishing the major revision, we skip this
					[ -n "${MAJOR_REVISION}" ] || continue
					SELECTOR="${RE_MAJOR_SELECTOR}"
					;;
			esac

			# What's the latest full version for this scope?
			SCOPED_LATEST="$(
				( echo "${ALL_REVISIONS}" ; echo "${REVISION_BASE_NUMBER}" ) | \
				grep -P "^${SELECTOR}$" | \
				sort --version-sort --unique --reverse | \
				head -1
			)"

			# This isn't the latest for this scope
			[ "${SCOPED_LATEST}" == "${REVISION_BASE_NUMBER}" ] || continue

			case "${V}" in
				# We're the latest version overall, for ALL available versions!
				# No need to look any further ...
				FULL ) IS_LATEST="true" ; break ;;

				# We're the latest version for this major-minor version group!
				MINOR ) IS_LATEST_MINOR="true" ;;

				# We're the latest version for this major version group!
				MAJOR ) IS_LATEST_MAJOR="true" ;;
			esac
		done

		if "${IS_LATEST}" ; then
			echo "Found latest ${LABEL} revision: ${REVISION_BASE_NUMBER}"
			LATEST="${REVISION_PREFIX}latest"
			BUILDS+=("${REG}/${IMAGE_URI}:${LATEST}")
			"${LATEST_ADDED}" || REVISIONS+=("${LATEST}")
			LATEST_ADDED="true"

			# Enable the other two if necessary ...
			[ -n "${MINOR_REVISION}" ] && IS_LATEST_MINOR="true"
			[ -n "${MAJOR_REVISION}" ] && IS_LATEST_MAJOR="true"
		fi

		if "${IS_LATEST_MINOR}" ; then
			echo "Found latest ${LABEL} minor revision: ${MINOR_REVISION}"
			LATEST="${REVISION_PREFIX}${MINOR_REVISION}-latest"
			BUILDS+=("${REG}/${IMAGE_URI}:${LATEST}")
			"${LATEST_MINOR_ADDED}" || REVISIONS+=("${LATEST}")
			LATEST_MINOR_ADDED="true"
		fi

		if "${IS_LATEST_MAJOR}" ; then
			echo "Found latest ${LABEL} major revision: ${MAJOR_REVISION}"
			LATEST="${REVISION_PREFIX}${MAJOR_REVISION}-latest"
			BUILDS+=("${REG}/${IMAGE_URI}:${LATEST}")
			"${LATEST_MAJOR_ADDED}" || REVISIONS+=("${LATEST}")
			LATEST_MAJOR_ADDED="true"
		fi
	done
fi

to_env BUILDS="$(echo -n "${BUILDS[@]}" | tr ' ' ',')"

# We only build to a single tag b/c the security scanner pukes otherwise
# (don't ask XD). We instead create out-of-band tags for the container
# image. This is OK, b/c the "AUTHORITATIVE_TAG" is the most exact tag
# that describes this specific build being executed right this second,
# and as such can be used as the image's canonical name.
#
# We do it like this to avoid having to modify the "docker push"
# section, below.
to_env AUTHORITATIVE_TAG="${PRIVATE_REGISTRY}/${IMAGE_URI}:${EXACT_REVISION}"

RC=0
(
	if [ "${KEEP_DOCKER_CACHE:-}" != "true" ] ; then
		echo "Cleaning out the Docker system..."
		docker system prune --all --force || true
	fi

	echo "Launching the Docker build..."
	set -x
	exec docker build "${BUILD_ARGS[@]}" --tag "${AUTHORITATIVE_TAG}" .
) || RC=${?}
find "${SECRETS_DIR}" -type f -exec shred -u "{}" ";" || true
rm -rf "${SECRETS_DIR}" || true
[ ${RC} -eq 0 ] || exit ${RC}

# Once the build succeeds, we create the required tags as appropriate
if [ -z "${REVISION_PRERELEASE}" ] ; then
	SCAN_REPORT_RETENTION_DAYS="90"
	TAG_PREFIX="release"
elif "${REVISION_SNAPSHOT}" ; then
	TAG_PREFIX="snapshot"
	SCAN_REPORT_RETENTION_DAYS="7"
else
	TAG_PREFIX="test"
	SCAN_REPORT_RETENTION_DAYS="30"
fi
to_env SCAN_REPORT_RETENTION_DAYS

[ "${VARIANT}" != "main" ] && TAG_PREFIX+="/${VARIANT}"

# If we want to tag the repository, do so! Clobber any existing tags!
echo "Creating Git tags for: ${REVISIONS[@]}"
if ! is_local_dev ; then
	for R in "${REVISIONS[@]}" ; do
		# Tags for GIT must be the *real* revision, with "+" instead of "_"
		git tag --force "${TAG_PREFIX}/${R//_/+}"
	done
fi

to_env REPORT_TARGET_PATH="${IMAGE_URI}/${REVISION_PREFIX}${REVISION_BASE_NUMBER}${REVISION_PRERELEASE}/b${GITHUB_RUN_NUMBER}+${REVISION_METADATA}"

ARTIFACT_IDENTIFIER=""
SCAN_COMP="true"
SCAN_VULN="true"
if is_local_dev ; then
	ARTIFACT_IDENTIFIER=".develop"
else
	case "${GITHUB_REF_NAME}" in
		main ) ;;
		develop ) ARTIFACT_IDENTIFIER=".${GITHUB_REF_NAME}" ;;

		# We only do vulnerability scanning for main, develop, and the FIPS branches
		* ) SCAN_COMP="false" ; SCAN_VULN="false" ;;
	esac
fi
to_env SCAN_COMP SCAN_VULN

# If we're running builds for multiple dynamic revisions,
# we have to append the revision to the artifact name
[ "${MATRIX_REVISION}" == "*" ] || ARTIFACT_IDENTIFIER+="-${MATRIX_REVISION}"

# If we're building a non-main variant, append the variant
[ "${VARIANT}" != "main" ] && ARTIFACT_IDENTIFIER+="-${VARIANT}"

# Save the final value
to_env ARTIFACT_IDENTIFIER

#
# The base place where scan data will be stored
#
SCAN_DIR_ROOT="${GITHUB_WORKSPACE}/security-scan"

# Always clean ALL OF IT out
sudo rm -rf "${SCAN_DIR_ROOT}"

# We MUST add a UUID in dev mode b/c in ACT
# environments the runners may end up sharing
# the same directory, so we don't want them
# clobbering each others' stuff
is_local_dev && SCAN_DIR+="/$(uuidgen)"

# Set! Now commit!
mkdir -p "${SCAN_DIR}"
to_env SCAN_DIR_ROOT SCAN_DIR

# TODO: account for the branch name!
to_env COMP_REPORT_BASE="compliance${ARTIFACT_IDENTIFIER}"
to_env COMP_REPORT_PATH="${SCAN_DIR}/${COMP_REPORT_BASE}"
to_env COMP_REPORT_PATTERN="${COMP_REPORT_PATH}.*"
to_env COMP_REPORT_XML_SOURCE="${COMP_REPORT_PATH}.xml"
to_env COMP_REPORT_HDF_SOURCE="${COMP_REPORT_PATH}.hdf"
to_env COMP_REPORT_HTML_SOURCE="${COMP_REPORT_PATH}.html"
to_env COMP_REPORT_SARIF_SOURCE="${COMP_REPORT_PATH}.sarif"

# TODO: account for the branch name!
to_env VULN_REPORT_BASE="vulnerabilities${ARTIFACT_IDENTIFIER}"
to_env VULN_REPORT_PATH="${SCAN_DIR}/${VULN_REPORT_BASE}"
to_env VULN_REPORT_PATTERN="${VULN_REPORT_PATH}.*"
to_env VULN_REPORT_JSON_SOURCE="${VULN_REPORT_PATH}.json"
to_env VULN_REPORT_HTML_SOURCE="${VULN_REPORT_PATH}.html"
to_env VULN_REPORT_SARIF_SOURCE="${VULN_REPORT_PATH}.sarif"
to_env VULN_REPORT_SBOM_SOURCE="${VULN_REPORT_PATH}.cdx"
