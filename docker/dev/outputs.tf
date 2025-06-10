# AWS VPC 모듈 관련 출력

output "aws_vpc_id" {
  description = "AWS VPC ID"
  value       = module.aws_vpc.vpc_id
}

output "aws_public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록 (AWS)"
  value       = module.aws_vpc.public_subnet_ids
}

output "aws_private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록 (AWS)"
  value       = module.aws_vpc.private_subnet_ids
}

# GCP VPC 모듈 관련 출력

output "gcp_network_name" {
  description = "GCP VPC 네트워크 이름"
  value       = module.gcp_vpc.network_name
}

output "gcp_network_id" {
  description = "GCP VPC 네트워크 ID"
  value       = module.gcp_vpc.network_id
}

output "gcp_private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록 (GCP)"
  value       = module.gcp_vpc.private_subnet_ids
}

# EC2 인스턴스 및 관련 정보

output "openvpn_instance_id" {
  description = "OpenVPN EC2 인스턴스 ID"
  value       = aws_instance.openvpn.id
}

output "openvpn_instance_public_ip" {
  description = "OpenVPN EC2의 공인 IP 주소"
  value       = aws_instance.openvpn.public_ip
}

output "openvpn_eip_allocation_id" {
  description = "OpenVPN 인스턴스에 연결된 EIP의 할당 ID"
  value       = aws_eip_association.eip_assoc.allocation_id
}

output "service_azone_instance_id" {
  description = "서비스(A) EC2 인스턴스 ID"
  value       = aws_instance.service_azone.id
}

output "service_azone_instance_private_ip" {
  description = "서비스(A) EC2 인스턴스의 프라이빗 IP"
  value       = aws_instance.service_azone.private_ip
}

output "service_czone_instance_id" {
  description = "서비스(C) EC2 인스턴스 ID"
  value       = aws_instance.service_czone.id
}

output "service_czone_instance_private_ip" {
  description = "서비스(C) EC2 인스턴스의 프라이빗 IP"
  value       = aws_instance.service_czone.private_ip
}

# GCE 인스턴스

output "gce_instance_name" {
  description = "GCP VM 인스턴스 이름"
  value       = google_compute_instance.gce.name
}

output "gce_instance_zone" {
  description = "GCP VM이 배포된 존"
  value       = google_compute_instance.gce.zone
}

output "gce_instance_network" {
  description = "GCE VM이 연결된 네트워크"
  value       = google_compute_instance.gce.network_interface[0].network
}

# ALB 및 대상 그룹

output "alb_dns_name" {
  description = "ALB DNS 이름"
  value       = aws_lb.alb.dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.alb.arn
}

output "alb_listener_https_arn" {
  description = "HTTPS ALB 리스너 ARN"
  value       = aws_lb_listener.https.arn
}

output "alb_target_group_arn" {
  description = "ALB 타겟 그룹 ARN"
  value       = aws_lb_target_group.fe_target_group.arn
}

# IAM, Key, 보안 그룹 등

output "iam_role_name" {
  description = "EC2 인스턴스용 IAM 역할 이름"
  value       = aws_iam_role.ec2_admin_role.name
}

output "iam_instance_profile_name" {
  description = "IAM 인스턴스 프로파일 이름"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}

output "key_pair_name" {
  description = "배포된 키페어 이름"
  value       = aws_key_pair.key.key_name
}

output "sg_openvpn_id" {
  description = "OpenVPN에 연결된 보안 그룹 ID"
  value       = aws_security_group.sg_openvpn.id
}

output "sg_private_id" {
  description = "Private 서비스에 연결된 보안 그룹 ID"
  value       = aws_security_group.sg_service.id
}

output "sg_alb_id" {
  description = "ALB에 연결된 보안 그룹 ID"
  value       = aws_security_group.sg_alb.id
}