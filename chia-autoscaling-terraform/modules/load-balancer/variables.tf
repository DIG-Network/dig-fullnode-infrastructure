variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of subnets for load balancer"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for load balancer"
  type        = string
}

variable "chia_port" {
  description = "Chia fullnode port"
  type        = number
}

variable "chia_rpc_port" {
  description = "Chia RPC port"
  type        = number
}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
}