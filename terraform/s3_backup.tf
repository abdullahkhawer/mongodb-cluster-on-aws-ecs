resource "aws_s3_bucket" "backup" {
  count = var.backup_enabled == true ? 1 : 0

  bucket = "${var.namespace}-${var.env_name}-mongodb-backups-bucket"

  tags = {
    Name        = "${var.namespace}-${var.env_name}-mongodb-backups-bucket"
    Environment = var.env_name
  }
}

resource "aws_s3_bucket_acl" "this" {
  count = var.backup_enabled == true ? 1 : 0

  bucket = aws_s3_bucket.backup[0].id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = var.backup_enabled == true ? 1 : 0

  bucket = aws_s3_bucket.backup[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.backup[0].arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.backup_enabled == true ? 1 : 0

  bucket = aws_s3_bucket.backup[0].id

  rule {
    id     = "backups"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 365
    }
  }
}