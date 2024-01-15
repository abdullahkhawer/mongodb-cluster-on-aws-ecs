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