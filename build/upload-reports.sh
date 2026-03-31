#!/bin/bash
. "${GITHUB_ACTION_FILE}/common.sh"

COUNT=0
while read SRC ; do
	echo "Uploading [${SRC}] to [s3://${REPORTS_BUCKET}/${REPORT_TARGET_PATH}]..."
	aws s3 cp "${SRC}" "s3://${REPORTS_BUCKET}/${REPORT_TARGET_PATH}/${SRC##*/}"
	(( ++COUNT ))
done < <(find . -mindepth 1 -maxdepth 1 -type f -name "${PATTERN}" | sort | cut -c3-)
[ ${COUNT} -eq 0 ] || echo "Uploaded ${COUNT} ${TYPE} report(s)!"
