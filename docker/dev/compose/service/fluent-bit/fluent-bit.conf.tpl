[SERVICE]
  Flush        5
  Daemon       Off
  Log_Level    info

[INPUT]
  Name   tail
  Path   /var/log/scouter-server.log
  Tag    scouter.log
  DB     /var/log/flb_tail_scouter.db
  Read_from_Head true

[INPUT]
  Name   tail
  Path   /var/log/cloud-init-output.log
  Tag    userdata.log
  DB     /var/log/flb_tail_userdata_service.db
  Read_from_Head true

[OUTPUT]
  Name cloudwatch_logs
  Match scouter.log
  region ap-northeast-2
  log_group_name scouter
  log_stream_name SERVICE-scouter-$(date +%Y-%m-%d)
  auto_create_group true

[OUTPUT]
  Name cloudwatch_logs
  Match userdata.log
  region ap-northeast-2
  log_group_name userdata
  log_stream_name SERVICE-userdata-$(date +%Y-%m-%d)
  auto_create_group true