data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_subnets" "this" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Name = var.private_subnet_tag_name
  }
}

data "aws_route53_zone" "this" {
  name         = var.hosted_zone_name
  private_zone = true
}

data "aws_ami" "amzlinux2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

locals {
  ec2_role_policies = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  ecs_task_role_policies = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess"
  ]

  aws_subnets_list      = tolist(data.aws_subnets.this.ids)
  aws_subnets_list_size = length(local.aws_subnets_list)
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  count = var.monitoring_enabled ? var.number_of_instances : 0

  alarm_name          = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  treat_missing_data  = var.alarm_treat_missing_data
  alarm_description   = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1} Container CPU Utilization"
  alarm_actions       = [var.aws_sns_topic]
  ok_actions          = [var.aws_sns_topic]

  dimensions = {
    ServiceName = "${var.service_name}${count.index + 1}"
    ClusterName = "${var.namespace}-${var.env_name}-${var.service_name}"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  count = var.monitoring_enabled ? var.number_of_instances : 0

  alarm_name          = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}-memory-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  treat_missing_data  = var.alarm_treat_missing_data
  alarm_description   = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1} Container Memory Utilization"
  alarm_actions       = [var.aws_sns_topic]
  ok_actions          = [var.aws_sns_topic]

  dimensions = {
    ServiceName = "${var.service_name}${count.index + 1}"
    ClusterName = "${var.namespace}-${var.env_name}-${var.service_name}"
  }
}

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
    ENABLE_MONITORING               = var.monitoring_enabled ? "YES" : "NO"
    ALARM_NAME_PREFIX               = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}"
    ALARM_TREAT_MISSING_DATA        = var.alarm_treat_missing_data
    ALARM_SNS_TOPIC                 = var.aws_sns_topic
    HOSTED_ZONE_ID                  = data.aws_route53_zone.this.zone_id
    DNS_NAME                        = "${var.env_name}-${var.service_name}${count.index + 1}.${var.hosted_zone_name}"
    BACKUP_S3_BUCKET_NAME           = "${var.namespace}-${var.env_name}-mongodb-backups-bucket"
    ENABLE_BACKUP                   = var.backup_enabled && count.index == 0 ? "YES" : "NO"
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
  vpc_zone_identifier = [local.aws_subnets_list[count.index % local.aws_subnets_list_size]]
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

resource "aws_ecs_cluster" "this" {
  name = "${var.namespace}-${var.env_name}-${var.service_name}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_service" "this" {
  count = var.number_of_instances

  name                               = "${var.service_name}${count.index + 1}"
  cluster                            = aws_ecs_cluster.this.id
  launch_type                        = "EC2"
  task_definition                    = aws_ecs_task_definition.this[count.index].arn
  force_new_deployment               = false
  desired_count                      = 1
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0
}

resource "aws_ecs_task_definition" "this" {
  count = var.number_of_instances

  family                   = "${var.service_name}${count.index + 1}-${var.env_name}"
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.task.arn
  network_mode             = "host"
  skip_destroy             = false

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:name == ${var.service_name}${count.index + 1}"
  }

  volume {
    name = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}-ebs"

    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "rexray/ebs"
      labels        = {}

      driver_opts = {
        volumetype    = var.volume_type
        size          = var.volume_size
        iops          = var.volume_iops
        encrypted     = var.volume_encrypted
        encryptionkey = var.volume_encryption_key == null ? aws_kms_key.ebs[0].arn : var.volume_encryption_key
      }
    }
  }

  volume {
    name      = "mongodb-keys"
    host_path = "/usr/bin/keys"
  }

  container_definitions = templatefile("${path.module}/templates/container-definition.json.tpl", {
    aws_region   = var.aws_region
    namespace    = var.namespace
    env_name     = var.env_name
    service_name = var.service_name
    name         = "${var.service_name}${count.index + 1}"
    image        = var.image
    cpu          = var.cpu
    memory       = var.memory
    privileged   = true
    command      = var.number_of_instances > 1 ? jsonencode(["--replSet", "rs0", "--keyFile", "/keys/mongodb.key"]) : jsonencode([])

    portMappings = jsonencode([
      {
        "protocol" : "tcp",
        "containerPort" : 27017,
        "hostPort" : 27017
      }
    ])

    mountPoints = jsonencode([
      {
        "containerPath" : "/data/db",
        "sourceVolume" : "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}-ebs"
      },
      {
        "containerPath" : "/keys",
        "sourceVolume" : "mongodb-keys"
      }
    ])

    secrets = jsonencode([
      {
        "name" : "MONGO_INITDB_ROOT_USERNAME",
        "valueFrom" : "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/docker/${var.env_name}/MONGODB_USERNAME"
      },
      {
        "name" : "MONGO_INITDB_ROOT_PASSWORD",
        "valueFrom" : "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/docker/${var.env_name}/MONGODB_PASSWORD"
      }
    ])
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.namespace}-${var.env_name}-${var.service_name}-ec2-profile"
  role = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "this" {
  count = length(local.ec2_role_policies)

  role       = aws_iam_role.this.name
  policy_arn = element(local.ec2_role_policies, count.index)
}

resource "aws_iam_role_policy" "ec2" {
  name = "${var.namespace}-${var.env_name}-${var.service_name}-ec2-inline-policy"
  role = aws_iam_role.this.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:CreateVolume",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:DeleteVolume",
        "ec2:DeleteSnapshot",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInstances",
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumeAttribute",
        "ec2:DescribeVolumeStatus",
        "ec2:DescribeSnapshots",
        "ec2:CopySnapshot",
        "ec2:DescribeSnapshotAttribute",
        "ec2:DetachVolume",
        "ec2:ModifySnapshotAttribute",
        "ec2:ModifyVolumeAttribute",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:EnableAlarmActions",
        "cloudwatch:PutCompositeAlarm",
        "cloudwatch:SetAlarmState"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService"
      ],
      "Resource": "arn:aws:ecs:${var.aws_region}:${var.account_id}:service/${var.namespace}-${var.env_name}-${var.service_name}/*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "s3_kms" {
  count = var.backup_enabled ? 1 : 0

  name = "${var.namespace}-${var.env_name}-${var.service_name}-s3-kms-inline-policy"
  role = aws_iam_role.this.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListAllMyBuckets"
      ],
      "Resource": [
        "arn:aws:s3:::*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:GetBucketLocation",
        "s3:AbortMultipartUpload",
        "s3:GetObjectAcl",
        "s3:GetObjectVersion",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
        "s3:GetObject",
        "s3:PutObjectAcl",
        "s3:PutObject",
        "s3:GetObjectVersionAcl"
      ],
      "Resource": [
        "arn:aws:s3:::${var.namespace}-${var.env_name}-mongodb-backups-bucket",
        "arn:aws:s3:::${var.namespace}-${var.env_name}-mongodb-backups-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": [
        "${aws_kms_key.backup[0].arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "this" {
  name = "${var.namespace}-${var.env_name}-${var.service_name}-ec2-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task" {
  count = length(local.ecs_task_role_policies)

  role       = aws_iam_role.task.name
  policy_arn = element(local.ecs_task_role_policies, count.index)
}

resource "aws_iam_role_policy" "task" {
  name = "${var.namespace}-${var.env_name}-${var.service_name}-task-role-policy"
  role = aws_iam_role.task.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "logs:CreateLogGroup",
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ec2:DescribeInstances",
          "route53:ListResourceRecordSets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "task" {
  name = "${var.namespace}-${var.env_name}-${var.service_name}-task-role"
  path = "/"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "ecs-tasks.amazonaws.com"
          },
          "Effect" : "Allow",
        }
      ]
    }
  )
}

resource "aws_kms_key" "backup" {
  count = var.backup_enabled ? 1 : 0

  description             = "AWS KMS key used to encrypt S3 bucket objects."
  deletion_window_in_days = 10
}

resource "aws_kms_key" "ebs" {
  count = var.volume_encrypted && var.volume_encryption_key == null ? 1 : 0

  description             = "AWS KMS key used to encrypt EBS volumes."
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "backup" {
  count = var.backup_enabled ? 1 : 0

  bucket = "${var.namespace}-${var.env_name}-mongodb-backups-bucket"

  tags = {
    Name        = "${var.namespace}-${var.env_name}-mongodb-backups-bucket"
    Environment = var.env_name
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = var.backup_enabled ? 1 : 0

  bucket = aws_s3_bucket.backup[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.backup[0].arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.backup_enabled ? 1 : 0

  bucket = aws_s3_bucket.backup[0].id

  rule {
    id     = "s3-intelligent-tiering-and-archival"
    status = "Enabled"

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

resource "aws_security_group" "this" {
  name        = "${var.namespace}-${var.env_name}-${var.service_name}-sg"
  description = "Security group to allow access to MongoDB"
  vpc_id      = data.aws_vpc.this.id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
    description = "Within VPC"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Self"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All"
  }

  tags = {
    Name = "${var.namespace}-${var.env_name}-${var.service_name}-sg"
  }
}

resource "aws_ssm_parameter" "mongodb_endpoints" {
  name        = "/docker/${var.env_name}/MONGODB_ENDPOINTS"
  description = "Parameter having MongoDB endpoints"
  type        = "SecureString"
  overwrite   = true
  value       = join(",", formatlist("${var.env_name}-${var.service_name}%s.${var.hosted_zone_name}", range(1, var.number_of_instances + 1)))

  tags = {
    Name        = "/docker/${var.env_name}/MONGODB_ENDPOINTS"
    Environment = var.env_name
  }
}

data "aws_instance" "this" {
  depends_on = [
    aws_autoscaling_group.this
  ]

  filter {
    name   = "tag:Name"
    values = ["${var.namespace}-${var.env_name}-${var.service_name}1"]
  }

  filter {
    name   = "instance-state-name"
    values = ["pending", "running"]
  }
}

resource "null_resource" "wait_for_instance" {
  depends_on = [
    aws_autoscaling_group.this
  ]

  triggers = {
    instance_id = data.aws_instance.this.id
  }

  provisioner "local-exec" {
    command = <<EOF
      timeout=600  # Timeout in seconds
      start_time=$(date +%s)

      until [ "$(aws ec2 describe-instance-status --instance-id ${self.triggers.instance_id} --query 'InstanceStatuses[0].InstanceStatus.Status' --output text)" = "ok" ] && \
            [ "$(aws ec2 describe-instance-status --instance-id ${self.triggers.instance_id} --query 'InstanceStatuses[0].SystemStatus.Status' --output text)" = "ok" ] && \
            [ "$(aws ec2 describe-instances --instance-ids ${self.triggers.instance_id} --query 'Reservations[0].Instances[0].State.Name' --output text)" = "running" ]; do
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))

        if [ "$elapsed_time" -ge "$timeout" ]; then
          echo "Timeout reached. Instance didn't reach the desired state within $timeout seconds."
          exit 1
        fi

        sleep 5
        echo "Waiting for instance to be running and complete status checks..."
      done

      echo "Instance is now running fine and status checks have been completed!"
    EOF
  }
}
