output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.chia_blockchain.id
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.chia_blockchain.dns_name
}

output "efs_mount_target_ids" {
  description = "IDs of the EFS mount targets"
  value       = aws_efs_mount_target.chia_blockchain[*].id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for blockchain snapshots"
  value       = aws_s3_bucket.blockchain_snapshots.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for blockchain snapshots"
  value       = aws_s3_bucket.blockchain_snapshots.arn
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.chia_instance.name
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.chia_instance.arn
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2 instances"
  value       = aws_iam_role.chia_instance.arn
}