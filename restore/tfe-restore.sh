#!/usr/bin/env bash

# Purpose: Check for a backup and restore
# Location: /etc/tfe/tfe-restore.sh

if [ -z "$1" ] ; then
  echo "First Argument Missing - s3_bucket_name"
  exit 1
fi
if [ -z "$2" ] ; then
  echo "First Argument Missing - backup_password"
  exit 1
fi

echo "[$(date +"%FT%T")]  Started Backup."
# Set intial start time - used to calculate total time
SECONDS=0

s3_bucket_name=$1
backup_password=$2
backup_token=$(replicatedctl app-config export | jq -r '.backup_token.value')

echo "Backup Settings:"
echo "  Password:   ${backup_password}"
echo "  Token:      ${backup_token}"
echo "  S3 Bucket:  ${s3_bucket_name}"
echo ""

echo "Searching for new backup"
touch /etc/tfe/current.backup
current_backup=$(cat /etc/tfe/current.backup)
latest_available_backup=$(aws s3api list-objects-v2 --bucket ${s3_bucket_name} --query 'reverse(sort_by(Contents,&LastModified))' | jq -r .[0].Key)
if [[ "$current_backup" == "$latest_available_backup" ]]; then
  echo "No New Backup Available, Current: ${current_backup}"
else
  echo "New Backup Available"
  echo "  Current: ${current_backup}"
  echo "  New:     ${latest_available_backup}"

  # update current backup file
  backup_name=${latest_available_backup}
  echo "${latest_available_backup}" > /etc/tfe/current.backup
  echo "{ \"password\": \"${backup_password}\" }" > /etc/tfe/backup_config.json

  echo "[$(date +"%FT%T")]  Copy Backup from S3"
  aws s3 cp s3://${s3_bucket_name}/${backup_name} ${backup_name}

  echo "[$(date +"%FT%T")]  Restore API Start"
  curl -k \
    --header "Authorization: Bearer ${backup_token}" \
    --request POST \
    --form config=@/etc/tfe/backup_config.json \
    --form snapshot=@${backup_name} \
    https://localhost/_backup/api/v1/restore
  echo "[$(date +"%FT%T")]  Restore API Finished"
  sleep 10

  echo "[$(date +"%FT%T")]  Restarting TFE"
  APP_STATE=$(replicatedctl app status | jq -r '.[].State')
  echo "Replicated app state before restart: $APP_STATE"
  replicatedctl app stop
  sleep 10
  until [[ $(replicatedctl app status | jq -r '.[].State') == "stopped" ]]; do
    sleep 2
    APP_STATE=$(replicatedctl app status | jq -r '.[].State')
    echo "Waiting for Replicated app to stop... Current state: $APP_STATE"
  done
  echo "Replicated app stopped. Preparing to start Replicated app."

  replicatedctl app start
  sleep 60
  until [[ $(replicatedctl app status | jq -r '.[].State') == "started" ]]; do
    sleep 2
    APP_STATE=$(replicatedctl app status | jq -r '.[].State')
    echo "Waiting for Replicated app to start... Current state: $APP_STATE"
  done
  echo "Replicated app started."
fi

duration=$SECONDS
echo "[$(date +"%FT%T")]  Finished Backup."
echo "  $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
