#!/bin/bash
source ./app-variables.sh
DB_FILE="../backup/careerbee_backup.sql"
if [ -f "${DB_FILE}" ]; then
    scp -i ${SSH_KEY} ${DB_FILE} ubuntu@${SERVER_IP}:~/tmp/$(basename ${DB_FILE})
    ssh -i $SSH_KEY ubuntu@$SERVER_IP "mysql -uroot -p"${DB_PASSWORD}" careerbee < ~/tmp/$(basename ${DB_FILE})"
    echo "========================================="
    echo "✅ DB 백업 파일 업로드 완료."
    echo "========================================="
else
    echo "========================================="
    echo "⚠️ ${DB_FILE} 파일이 존재하지 않아 업로드를 건너뜁니다."
    echo "========================================="
fi
ssh -i $SSH_KEY ubuntu@$SERVER_IP <<EOF
if [ -f ~/tmp/$(basename ${DB_FILE}) ]; then
    mysql -uroot -p"${DB_PASSWORD}" "${DB_NAME}" < ~/tmp/$(basename ${DB_FILE})
    
    echo "========================================="
    echo "📊 복원된 테이블의 정확한 레코드 수:"
    echo "========================================="
    mysql -uroot -p"${DB_PASSWORD}" -D "${DB_NAME}" -N -e "
      SET SESSION group_concat_max_len = 1000000;
      SELECT CONCAT(
        'SELECT \"', table_name, '\" AS 테이블명, COUNT(*) AS 레코드수 FROM ', table_name, ';'
      )
      FROM information_schema.tables
      WHERE table_schema = '${DB_NAME}' AND table_type = 'BASE TABLE';" \
    | mysql -uroot -p"${DB_PASSWORD}" -D "${DB_NAME}"

    echo "========================================="
    echo "✅ MySQL 복원 완료!"
    echo "========================================="
else
    echo "========================================="
    echo "⚠️ careerbee_backup.sql 파일이 없어 복원을 건너뜁니다."
    echo "========================================="
fi
EOF