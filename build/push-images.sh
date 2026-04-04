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
is_local_dev && [ "${LOCAL_PUBLISH:-}" != "true" ] && CMD="running"

#
# Iterate over the array of built artifacts, and push them
#
for BUILD in "${BUILDS[@]}" ; do
	echo "Pushing [${BUILD}] ..."
	if [ "${TAGS_ADDED:-false}" != "true" ] && [ "${AUTHORITATIVE_TAG}" != "${BUILD}" ] ; then
		echo -e "\tTagging [${AUTHORITATIVE_TAG}] as [${BUILD}] ..."
		( execute docker tag "${AUTHORITATIVE_TAG}" "${BUILD}" ) || exit ${?}
	fi
	( "${CMD}" docker push "${BUILD}" ) || exit ${?}
done
