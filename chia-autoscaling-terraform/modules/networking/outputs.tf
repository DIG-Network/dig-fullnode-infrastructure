output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "chia_nodes_security_group_id" {
  description = "ID of the security group for Chia nodes"
  value       = aws_security_group.chia_nodes.id
}

output "efs_security_group_id" {
  description = "ID of the security group for EFS"
  value       = aws_security_group.efs.id
}

output "load_balancer_security_group_id" {
  description = "ID of the security group for Load Balancer"
  value       = aws_security_group.load_balancer.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways"
  value       = aws_nat_gateway.main[*].id
}

output "availability_zones" {
  description = "Availability zones used"
  value       = var.availability_zones
}