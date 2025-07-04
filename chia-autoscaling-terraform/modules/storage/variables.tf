variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of subnets for EFS mount targets"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for EFS"
  type        = string
}

variable "efs_performance_mode" {
  description = "EFS performance mode"
  type        = string
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode"
  type        = string
}

variable "backup_retention_days" {
  description = "S3 backup retention days"
  type        = number
}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
}