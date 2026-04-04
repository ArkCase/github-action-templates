#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

# Turn the command into a dud in development mode
is_local_dev && MODE="running" || MODE=""

COUNT=0
while read SRC ; do
	echo "Uploading [${SRC}] to [s3://${REPORTS_BUCKET}/${REPORT_TARGET_PATH}]..."
	# This trick allows us to turn the command into a dud if we so choose (see above!)
	${MODE} aws s3 cp "${SRC}" "s3://${REPORTS_BUCKET}/${REPORT_TARGET_PATH}/${SRC##*/}"
	(( ++COUNT ))
done < <(find . -mindepth 1 -maxdepth 1 -type f -name "${PATTERN}" | sort | cut -c3-)
[ ${COUNT} -eq 0 ] || echo "Uploaded ${COUNT} ${TYPE} report(s)!"
