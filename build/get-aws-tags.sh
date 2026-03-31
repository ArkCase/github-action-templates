#!/bin/bash

JQ_FIND_IMAGE_TAGS='.imageDetails[] | select(has("imageTags")) | .imageTags[]'

aws "${ECR}" describe-images --repository-name "${QUERY}" | jq -r "${JQ_FIND_IMAGE_TAGS}"
