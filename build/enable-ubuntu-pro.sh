#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

sudo apt-get update || fail "Failed to update the Ubuntu repositories (rc=${?})"

sudo apt-get install -y ubuntu-pro-client || fail "Failed to install the ubuntu-pro-client package (rc=${?})"
sudo rm -rf /var/lib/apt/lists/* || warn "Failed to clear out the APT lists directory (rc=${?})"

RC=0
sudo pro attach --no-auto-enable "${@}" || RC=${?}
case ${RC} in
	0 ) ok "Ubuntu Pro attached!" ; exit 0 ;;
	2 ) ok "Already attached to Ubuntu Pro!" ; exit 0 ;;
esac
err "Failed to attach to Ubuntu Pro (rc=${RC})"
exit ${RC}
