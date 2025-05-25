#!/bin/bash
source ./app-variables.sh # cd deploy/scripts

LATEST_BACKUP=$(aws s3 ls ${S3_BUCKET_INFRA}/db/ | sort | tail -n 1 | awk '{print $4}')
LOCAL_RESTORE_FILE="/tmp/$LATEST_BACKUP"

ssh -i $SSH_KEY ubuntu@$AWS_SERVER_IP << EOF
aws s3 cp ${S3_BUCKET_INFRA}/db/$LATEST_BACKUP $LOCAL_RESTORE_FILE

mysql -u root -p"${DB_PASSWORD}" careerbee < $LOCAL_RESTORE_FILE

rm $LOCAL_RESTORE_FILE
EOF