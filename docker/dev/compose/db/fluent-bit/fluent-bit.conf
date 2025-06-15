[SERVICE]
  Flush        5
  Daemon       Off
  Log_Level    info

[INPUT]
  Name   tail
  Path   /var/log/cloud-init-output.log
  Tag    userdata.log
  DB     /var/log/flb_tail_userdata_db.db
  Read_from_Head true

[OUTPUT]
  Name cloudwatch_logs
  Match userdata.log
  region ap-northeast-2
  log_group_name userdata
  log_stream_name DB-userdata-$(date +%Y-%m-%d)
  auto_create_group true