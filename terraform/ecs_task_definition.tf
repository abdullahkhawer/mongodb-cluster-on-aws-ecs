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
