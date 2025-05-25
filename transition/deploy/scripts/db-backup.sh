#!/bin/bash
source ./app-variables.sh # cd deploy/scripts

VERSION_TAG=$(date +v%Y%m%d%H%M%S)
FILE="backup-${VERSION_TAG}.sql"

ssh -i $SSH_KEY ubuntu@$AWS_SERVER_IP << EOF
mysqldump -u root -p"${DB_PASSWORD}" careerbee > $FILE

aws s3 cp $FILE ${S3_BUCKET_INFRA}/db/

rm $FILE
EOF