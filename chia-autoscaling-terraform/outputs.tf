# Network Load Balancer outputs
output "load_balancer_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = module.load_balancer.nlb_dns_name
}

output "load_balancer_arn" {
  description = "ARN of the Network Load Balancer"
  value       = module.load_balancer.nlb_arn
}

# EFS outputs
output "efs_id" {
  description = "ID of the EFS file system"
  value       = module.storage.efs_id
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = module.storage.efs_dns_name
}

# S3 outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for blockchain snapshots"
  value       = module.storage.s3_bucket_name
}

# Auto Scaling Group outputs
output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.autoscaling_group_name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = module.compute.autoscaling_group_arn
}

# VPC outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr
}

# CloudWatch outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Chia logs"
  value       = module.compute.cloudwatch_log_group_name
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.chia_monitoring.dashboard_name}"
}

# Connection information
output "chia_fullnode_endpoint" {
  description = "Endpoint for Chia fullnode connections"
  value       = "${module.load_balancer.nlb_dns_name}:${var.chia_port}"
}

output "chia_rpc_endpoint" {
  description = "Endpoint for Chia RPC connections"
  value       = "${module.load_balancer.nlb_dns_name}:${var.chia_rpc_port}"
}

# Instance profile for manual EC2 launches
output "instance_profile_name" {
  description = "Name of the IAM instance profile for EC2 instances"
  value       = module.storage.instance_profile_name
}