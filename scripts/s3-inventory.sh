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

ROLE_NAME="FederatedAccess"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="s3-inventory/s3-inventory_${TIMESTAMP}.csv"
LOG_FILE="s3-inventory/s3-inventory.log"

# Tee all output to log file (append)
exec > >(tee -a "$LOG_FILE") 2>&1

echo ""
echo "========================================"
echo "Session started: $TIMESTAMP"
echo "Output CSV: $OUTPUT_FILE"
echo "========================================"

# CSV Header
echo "AccountId,BucketName,CreationDate,Region,SizeBytes,ObjectCount,LastWrite,LastRead" > $OUTPUT_FILE

for ACCOUNT_ID in "${ACCOUNTS[@]}"; do
  echo ""
  echo "Processing account: $ACCOUNT_ID"
  echo "----------------------------------------"

  # Assume role
  CREDS=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
    --role-session-name "InventorySession" \
    --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
    --output text 2>/dev/null)

  if [ -z "$CREDS" ] || [ "$CREDS" == "None" ]; then
    echo "  ERROR: Failed to assume role in $ACCOUNT_ID — skipping"
    echo "${ACCOUNT_ID},ROLE_ASSUMPTION_FAILED,,,,,,," >> $OUTPUT_FILE
    continue
  fi

  export AWS_ACCESS_KEY_ID=$(echo $CREDS | awk '{print $1}')
  export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | awk '{print $2}')
  export AWS_SESSION_TOKEN=$(echo $CREDS | awk '{print $3}')

  # Verify assumed identity
  ASSUMED=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
  printf "  Assumed account verified: $ASSUMED\n"

  # Get all buckets with creation dates
  BUCKETS=$(aws s3api list-buckets \
    --query "Buckets[].[Name,CreationDate]" \
    --output text 2>/dev/null)

  if [ -z "$BUCKETS" ]; then
    echo "  No buckets found in account $ACCOUNT_ID"
    echo "${ACCOUNT_ID},NO_BUCKETS_FOUND,,,,,,," >> $OUTPUT_FILE

    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    continue
  fi

  while IFS=$'\t' read -r BUCKET_NAME CREATION_DATE; do

    BUCKET_NAME=$(echo "$BUCKET_NAME" | tr -d '\r\n')
    CREATION_DATE=$(echo "$CREATION_DATE" | tr -d '\r\n')

    [ -z "$BUCKET_NAME" ] && continue

    printf "  Processing: $BUCKET_NAME..."

    # Get bucket region
    REGION=$(aws s3api get-bucket-location \
      --bucket "$BUCKET_NAME" \
      --query "LocationConstraint" \
      --output text 2>/dev/null)
    [ "$REGION" == "None" ] || [ "$REGION" == "null" ] && REGION="us-east-1"

    # Get size from CloudWatch
    SIZE=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/S3 \
      --metric-name BucketSizeBytes \
      --dimensions Name=BucketName,Value="$BUCKET_NAME" Name=StorageType,Value=StandardStorage \
      --start-time $(date -u -d '2 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2d +%Y-%m-%dT%H:%M:%SZ) \
      --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
      --period 86400 \
      --statistics Average \
      --region "$REGION" \
      --query "sort_by(Datapoints, &Timestamp)[-1].Average" \
      --output text 2>/dev/null)
    [ "$SIZE" == "None" ] || [ -z "$SIZE" ] && SIZE="N/A"

    # Get object count from CloudWatch
    OBJECT_COUNT=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/S3 \
      --metric-name NumberOfObjects \
      --dimensions Name=BucketName,Value="$BUCKET_NAME" Name=StorageType,Value=AllStorageTypes \
      --start-time $(date -u -d '2 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-2d +%Y-%m-%dT%H:%M:%SZ) \
      --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
      --period 86400 \
      --statistics Average \
      --region "$REGION" \
      --query "sort_by(Datapoints, &Timestamp)[-1].Average" \
      --output text 2>/dev/null)
    [ "$OBJECT_COUNT" == "None" ] || [ -z "$OBJECT_COUNT" ] && OBJECT_COUNT="N/A"

    # Get last write via CloudTrail
    LAST_WRITE=$(aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET_NAME" \
      --max-results 1 \
      --query "Events[?contains(EventName,'Put') || contains(EventName,'Write')].EventTime | [0]" \
      --region "$REGION" \
      --output text 2>/dev/null)
    [ "$LAST_WRITE" == "None" ] || [ -z "$LAST_WRITE" ] && LAST_WRITE="N/A"

    # Get last read via CloudTrail
    LAST_READ=$(aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=ResourceName,AttributeValue="$BUCKET_NAME" \
      --max-results 1 \
      --query "Events[?contains(EventName,'Get') || contains(EventName,'List')].EventTime | [0]" \
      --region "$REGION" \
      --output text 2>/dev/null)
    [ "$LAST_READ" == "None" ] || [ -z "$LAST_READ" ] && LAST_READ="N/A"

    echo "${ACCOUNT_ID},${BUCKET_NAME},${CREATION_DATE},${REGION},${SIZE},${OBJECT_COUNT},${LAST_WRITE},${LAST_READ}" >> $OUTPUT_FILE

    printf "\r  Processing: $BUCKET_NAME done.\n"

  done <<< "$BUCKETS"

  # Clear credentials before next account
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

done

echo ""
echo "========================================"
echo "Session completed: $(date +%Y%m%d_%H%M%S)"
echo "Inventory file: $OUTPUT_FILE"
echo "Log file: $LOG_FILE"
echo "========================================"
