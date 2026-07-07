#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

# Turn the command into a dud in development mode
is_local_dev && MODE="running" || MODE=""

COUNT=0
while read SRC ; do
	SRC_BASE="${SRC##*/}"
	say "Uploading [${SRC_BASE}] to [s3://${REPORTS_BUCKET}/${REPORT_TARGET_PATH}]..."
	# This trick allows us to turn the command into a dud if we so choose (see above!)
	${MODE} aws s3 cp "${SRC}" "s3://${REPORTS_BUCKET}/${REPORT_TARGET_PATH}/${SRC_BASE}"
	(( ++COUNT ))
done < <(find "${SCAN_TGT_DIR}" -mindepth 1 -maxdepth 1 -type f -name "${TYPE}*" | sort)
[ ${COUNT} -eq 0 ] && ok "No ${TYPE} reports found to upload!" || ok "Uploaded ${COUNT} ${TYPE} report(s)!"
