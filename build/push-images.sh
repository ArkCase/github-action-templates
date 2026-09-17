#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

#
# BUILDS is a CSV whose values can't have spaces, so split it!
#
BUILDS=( ${BUILDS//,/ } )

#
# Decide whether the work needs to be done, or just say it was done
#
CMD="execute"
GET_DIGEST="true"
if is_local_dev && [ "${LOCAL_PUBLISH:-}" != "true" ] ; then
	CMD="running"
	GET_DIGEST="false"
fi

#
# Iterate over the array of built artifacts, and push them
#
for BUILD in "${BUILDS[@]}" ; do
	say "Pushing [${BUILD}] ..."
	if [ "${TAGS_ADDED:-false}" != "true" ] && [ "${AUTHORITATIVE_TAG}" != "${BUILD}" ] ; then
		say "\tTagging [${AUTHORITATIVE_TAG}] as [${BUILD}] ..."
		( execute docker tag "${AUTHORITATIVE_TAG}" "${BUILD}" ) || exit ${?}
	fi
	( "${CMD}" docker push "${BUILD}" ) || exit ${?}
done

if [ "${GET_DIGEST}" == "true" ] ; then
	REPO_DIGEST="$(docker inspect --format="{{ index .RepoDigests 0 }}" "${AUTHORITATIVE_TAG}" 2>&1)" || fail "Failed to retrieve the digest for the image as [${AUTHORITATIVE_TAG}] (rc=${?}): ${DIGEST}"
	IMAGE_DIGEST="${REPO_DIGEST#*@}"
	ok "\tThe image was published with the digest ${IMAGE_DIGEST}"
else
	IMAGE_DIGEST="unknown:no-digest-available"
fi
to_env IMAGE_DIGEST
