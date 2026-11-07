#!/bin/bash

# List of all the target account IDs
ACCOUNTS=(
  # o-tztq33ltnw
  "801610064192"

  "568354555100"
  "640693977485"
  "126159560176"

  "743122510778"
  "341292795870"
  "864981721433"

  # o-tztq33ltnw
  "802807423235"
  "956474664196"
)

# Override
ACCOUNTS=(
  # o-tztq33ltnw
  # "801610064192"

  # o-tztq33ltnw
  "802807423235"
  # "956474664196"
)
INCLUDED_BUCKETS=(
  # o-tztq33ltnw
  # "801610064192"
  "aws-sam-cli-managed-dev-pi-artifactsloggingbucket-3ehfjv0mkbu5"
  "elb-access-logs-marinov"

  # o-tztq33ltnw
  # "802807423235"
  "cv-generator-life-log-cf-logs"
  # "cv-generator-life-log-data-lake"
  # "orion-papers-1"
  # "securityhub-s3-bucket-logging-enabled-a887f824-common"

  # o-tztq33ltnw
  # "956474664196"
  "aws-cloudtrail-logs-956474664196-259b16e6-server-access-logging"
  "aws-cloudtrail-logs-956474664196-259b16e6"
)
ACCOUNTS=(
  # o-tztq33ltnw
  "802807423235"
)
INCLUDED_BUCKETS=(
  # o-tztq33ltnw
  # "802807423235"
  "cv-generator-life-log-cf-logs"
)

ROLE_NAME="FederatedAccess"
# POLICY_FILE="file://change-lifecycle_policy/lifecycle_policy/lifecycle-policy.json"
POLICY_FILE=$(python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(open("change-lifecycle_policy/lifecycle_policy/lifecycle-policy.yaml"))))')
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="change-lifecycle_policy/change-lifecycle_policy.log"

DRY_RUN=false
# DRY_RUN=true

# Color codes
GRAY='\033[0;90m'
BLACK='\033[1;90m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Logger function - prints to console with color, writes plain text to log
log() {
  printf -- "%b" "$1"
  printf -- "%b" "$1" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
}

# Tee all output to log file (append), stripping ANSI codes from log
exec > >(tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1

log "\n"
log "========================================\n"
log "Session started: $TIMESTAMP\n"
log "========================================\n"

for ACCOUNT_ID in "${ACCOUNTS[@]}"; do
log "\n"
log "Processing account: $ACCOUNT_ID\n"
log "----------------------------------------\n"

  # Assume the role in the target account
  CREDS=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
    --role-session-name "LifecyclePolicySession" \
    --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
    --output text 2>/dev/null)

  if [ -z "$CREDS" ] || [ "$CREDS" == "None" ]; then
    log "  ${RED}ERROR: Failed to assume role in $ACCOUNT_ID — skipping${RESET}\n"
    continue
  fi

  # Parse credentials
  export AWS_ACCESS_KEY_ID=$(echo $CREDS | awk '{print $1}')
  export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | awk '{print $2}')
  export AWS_SESSION_TOKEN=$(echo $CREDS | awk '{print $3}')

  # Iterate all buckets in the assumed account
  for bucket in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do

    # Skip non-whitelisted buckets
    if [[ ! " ${INCLUDED_BUCKETS[@]} " =~ " ${bucket} " ]]; then
      log "  ${GRAY}Skipping: $bucket${RESET}\n"
      continue
    fi

    log "    ${GRAY}Applying lifecycle policy: $bucket..."
    if [[ "$DRY_RUN" == true ]]; then
      log "\r    ${GRAY}Applying lifecycle policy: ${WHITE}$bucket${GRAY}... INFO: DRY_RUN is true. ${YELLOW}Skipped${RESET}.\n"
    else
      log "\r    ${GRAY}Applying lifecycle policy: ${WHITE}$bucket${GRAY}... ${GREEN}done${RESET}.\n"
      aws s3api put-bucket-lifecycle-configuration \
        --bucket "$bucket" \
        --lifecycle-configuration "$POLICY_FILE"
    fi

  done

  # Clear credentials before next iteration
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

done

log "\n"
log "========================================\n"
log "Session completed: $(date +%Y%m%d_%H%M%S)\n"
log "Log file: $LOG_FILE\n"
log "========================================\n"
