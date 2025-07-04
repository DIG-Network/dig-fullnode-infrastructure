variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "chia_port" {
  description = "Chia fullnode port"
  type        = number
}

variable "chia_rpc_port" {
  description = "Chia RPC port"
  type        = number
}

variable "chia_farmer_port" {
  description = "Chia farmer port"
  type        = number
}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
}