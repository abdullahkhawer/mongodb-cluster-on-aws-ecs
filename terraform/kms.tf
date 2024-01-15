resource "aws_kms_key" "backup" {
  count = var.backup_enabled == true ? 1 : 0

  description             = "AWS KMS key used to encrypt S3 bucket objects."
  deletion_window_in_days = 10
}

resource "aws_kms_key" "ebs" {
  count = var.volume_encrypted == true && var.volume_encryption_key == null ? 1 : 0

  description             = "AWS KMS key used to encrypt EBS volumes."
  deletion_window_in_days = 10
}