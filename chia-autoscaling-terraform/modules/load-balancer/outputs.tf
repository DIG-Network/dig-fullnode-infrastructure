output "nlb_id" {
  description = "ID of the Network Load Balancer"
  value       = aws_lb.chia.id
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = aws_lb.chia.arn
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.chia.dns_name
}

output "nlb_zone_id" {
  description = "Zone ID of the Network Load Balancer"
  value       = aws_lb.chia.zone_id
}

output "target_group_fullnode_arn" {
  description = "ARN of the fullnode target group"
  value       = aws_lb_target_group.chia_fullnode.arn
}

output "target_group_rpc_arn" {
  description = "ARN of the RPC target group"
  value       = aws_lb_target_group.chia_rpc.arn
}

output "target_group_health_arn" {
  description = "ARN of the health check target group"
  value       = aws_lb_target_group.chia_health.arn
}

output "target_group_arns" {
  description = "List of all target group ARNs"
  value = [
    aws_lb_target_group.chia_fullnode.arn,
    aws_lb_target_group.chia_rpc.arn,
    aws_lb_target_group.chia_health.arn
  ]
}