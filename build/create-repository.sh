#!/bin/bash
. "${GITHUB_ACTION_PATH}/common.sh"

# All images have private repositories
echo "Creating the private repository for ${IMAGE_URI}..."
CMD=(
	aws ecr create-repository
		--repository-name "${IMAGE_URI}"
		--region "${AWS_REGION}"
		--image-tag-mutability MUTABLE
		--image-scanning-configuration scanOnPush=true
		--encryption-configuration encryptionType="AES256"
)
is_local_dev && CMD=( running "${CMD[@]}" )
"${CMD[@]}" || true

"${PUSH_TO_PUBLIC}" || exit 0

IMAGE_REAL_URI="${IMAGE_URI}"
[[ "${IMAGE_URI}" =~ ^arkcase/(.*)$ ]] && IMAGE_REAL_URI="${BASH_REMATCH[1]}"

echo "Creating the public repository for ${IMAGE_URI} (as ${IMAGE_REAL_URI})..."
CMD=(
	aws ecr-public create-repository
		--repository-name "${IMAGE_REAL_URI}"
		--region "${AWS_REGION}"
)

is_local_dev && CMD=( running "${CMD[@]}" )
"${CMD[@]}" || true

exit 0
