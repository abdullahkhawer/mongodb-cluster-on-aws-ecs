resource "aws_launch_template" "this" {
  count = var.number_of_instances

  name                   = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}-launch-template"
  image_id               = data.aws_ami.amzlinux2.id
  instance_type          = var.instance_type
  key_name               = var.ec2_key_pair_name
  ebs_optimized          = true
  vpc_security_group_ids = [aws_security_group.this.id]
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type = var.volume_type
      volume_size = 30
      iops        = var.volume_iops
      encrypted   = var.volume_encrypted
      kms_key_id  = var.volume_encryption_key == null ? aws_kms_key.ebs[0].arn : var.volume_encryption_key
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", {
    ECS_CLUSTER                     = aws_ecs_cluster.this.name
    ECS_INSTANCE_ATTRIBUTES         = "{\"name\":\"${var.service_name}${count.index + 1}\"}"
    AWS_REGION                      = var.aws_region
    ASG_NAME                        = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}-asg"
    LINE                            = "$LINE"
    ENABLE_MONITORING               = var.monitoring_enabled == true ? "YES" : "NO"
    ALARM_NAME_PREFIX               = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}"
    ALARM_TREAT_MISSING_DATA        = var.alarm_treat_missing_data
    ALARM_SNS_TOPIC                 = var.aws_sns_topic
    HOSTED_ZONE_ID                  = data.aws_route53_zone.this.zone_id
    DNS_NAME                        = "${var.env_name}-${var.service_name}${count.index + 1}.${var.hosted_zone_name}"
    BACKUP_S3_BUCKET_NAME           = "${var.namespace}-${var.env_name}-mongodb-backups-bucket"
    ENABLE_BACKUP                   = var.backup_enabled == true && count.index == 0 ? "YES" : "NO"
    MONGODB_USER_PARAMETER_NAME     = "/docker/${var.env_name}/MONGODB_USERNAME"
    MONGODB_PASSWORD_PARAMETER_NAME = "/docker/${var.env_name}/MONGODB_PASSWORD"
    MONGODB_KEYFILE_PARAMETER_NAME  = "/docker/${var.env_name}/MONGODB_KEYFILE"
    MONGO_DATABASES                 = var.mongodb_backup_databases
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}"
    }
  }
}

resource "aws_autoscaling_group" "this" {
  count = var.number_of_instances

  name                = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}-asg"
  vpc_zone_identifier = [tolist(data.aws_subnets.this.ids)[count.index]]
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.this[count.index].id
    version = aws_launch_template.this[count.index].latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 0
    }
  }
}