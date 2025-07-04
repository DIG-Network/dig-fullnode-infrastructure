# Create EFS file system
resource "aws_efs_file_system" "chia_blockchain" {
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode
  encrypted        = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chia-blockchain"
  })
}

# Create EFS mount targets
resource "aws_efs_mount_target" "chia_blockchain" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.chia_blockchain.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [var.security_group_id]
}

# Create EFS backup policy
resource "aws_efs_backup_policy" "chia_blockchain" {
  file_system_id = aws_efs_file_system.chia_blockchain.id

  backup_policy {
    status = "ENABLED"
  }
}

# Create S3 bucket for blockchain snapshots
resource "aws_s3_bucket" "blockchain_snapshots" {
  bucket = "${var.project_name}-${var.environment}-blockchain-snapshots-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-blockchain-snapshots"
  })
}

# Enable versioning on S3 bucket
resource "aws_s3_bucket_versioning" "blockchain_snapshots" {
  bucket = aws_s3_bucket.blockchain_snapshots.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Configure S3 bucket lifecycle
resource "aws_s3_bucket_lifecycle_configuration" "blockchain_snapshots" {
  bucket = aws_s3_bucket.blockchain_snapshots.id

  rule {
    id     = "expire-old-snapshots"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "blockchain_snapshots" {
  bucket = aws_s3_bucket.blockchain_snapshots.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to S3 bucket
resource "aws_s3_bucket_public_access_block" "blockchain_snapshots" {
  bucket = aws_s3_bucket.blockchain_snapshots.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM role for EC2 instances
resource "aws_iam_role" "chia_instance" {
  name_prefix = "${var.project_name}-${var.environment}-chia-instance-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for EFS access
resource "aws_iam_policy" "efs_access" {
  name_prefix = "${var.project_name}-${var.environment}-efs-access-"
  description = "Policy for Chia instances to access EFS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets"
        ]
        Resource = aws_efs_file_system.chia_blockchain.arn
      }
    ]
  })
}

# IAM policy for S3 access
resource "aws_iam_policy" "s3_access" {
  name_prefix = "${var.project_name}-${var.environment}-s3-access-"
  description = "Policy for Chia instances to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.blockchain_snapshots.arn,
          "${aws_s3_bucket.blockchain_snapshots.arn}/*"
        ]
      }
    ]
  })
}

# IAM policy for CloudWatch logs
resource "aws_iam_policy" "cloudwatch_logs" {
  name_prefix = "${var.project_name}-${var.environment}-cloudwatch-logs-"
  description = "Policy for Chia instances to write CloudWatch logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach policies to IAM role
resource "aws_iam_role_policy_attachment" "efs_access" {
  role       = aws_iam_role.chia_instance.name
  policy_arn = aws_iam_policy.efs_access.arn
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.chia_instance.name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.chia_instance.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.chia_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create instance profile
resource "aws_iam_instance_profile" "chia_instance" {
  name_prefix = "${var.project_name}-${var.environment}-chia-instance-"
  role        = aws_iam_role.chia_instance.name
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}