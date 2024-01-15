resource "aws_ecs_cluster" "this" {
  name = "${var.namespace}-${var.env_name}-${var.service_name}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}