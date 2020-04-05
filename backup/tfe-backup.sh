#!/usr/bin/env bash

# Purpose: Create a Backup, Upload to S3, and Cleanup
# Location: /etc/tfe/tfe-backup.sh

if [ -z "$1" ] ; then
  echo "Argument Missing - backup_s3_bucket_name"
  exit 1
fi
if [ -z "$2" ] ; then
  echo "Argument Missing - backup_password"
  exit 1
fi
if [ -z "$3" ] ; then
  echo "Argument Missing - backups_to_retain"
  exit 1
fi

echo "[$(date +"%FT%T")]  Started Backup."
# Set intial start time - used to calculate total time
SECONDS=0

backup_s3_bucket_name=$1
backup_password=$2
backups_to_retain=$3
current_time=$(date "+%Y.%m.%d-%H.%M.%S")
backup_name="${current_time}.backup"
backup_token=$(replicatedctl app-config export | jq -r '.backup_token.value')

echo "Backup Settings:"
echo "  Password:   ${backup_password}"
echo "  Token:      ${backup_token}"
echo "  Name:       ${backup_name}"
echo "  S3 Bucket:  ${backup_s3_bucket_name}"
echo ""

echo "[$(date +"%FT%T")]  Creating Backup"
echo "{ \"password\": \"${backup_password}\" }" > backup_config.json
curl -k \
  --header "Authorization: Bearer ${backup_token}" \
  --request POST \
  --output ${backup_name} \
  --data @backup_config.json \
  https://localhost/_backup/api/v1/backup

echo "[$(date +"%FT%T")]  Copy Backup to S3"
aws s3 cp ${backup_name} s3://${backup_s3_bucket_name}/${backup_name}
# read file info
aws s3 ls s3://${backup_s3_bucket_name}/${backup_name} --summarize
# validate?

echo "Searching for object retention"
objects_to_delete=$(aws s3api list-objects-v2 --bucket ${backup_s3_bucket_name} --query 'reverse(sort_by(Contents,&LastModified))' | jq -c --arg backup_count ${backups_to_retain} '[.[$backup_count|tonumber:] | .[] | {Key}] | {Objects: .}')
to_delete=$(echo ${objects_to_delete} | jq '.Objects | length')
echo "Found ${to_delete} to delete."

if [[ ${to_delete} -gt 0 ]]; then
  echo "Deleting objects"
  echo ${objects_to_delete} | jq .Objects[].Key
  aws s3api delete-objects --bucket ${backup_s3_bucket_name} --delete "${objects_to_delete}"
fi

duration=$SECONDS
echo "[$(date +"%FT%T")]  Finished Backup."
echo "  $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
