resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  count = var.monitoring_enabled == true ? var.number_of_instances : 0

  alarm_name          = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  treat_missing_data  = var.alarm_treat_missing_data
  alarm_description   = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1} Container CPU Utilization"
  alarm_actions       = [var.aws_sns_topic]
  ok_actions          = [var.aws_sns_topic]

  dimensions = {
    ServiceName = "${var.service_name}${count.index + 1}"
    ClusterName = "${var.namespace}-${var.env_name}-${var.service_name}-cluster"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  count = var.monitoring_enabled == true ? var.number_of_instances : 0

  alarm_name          = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1}-memory-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"
  treat_missing_data  = var.alarm_treat_missing_data
  alarm_description   = "${var.namespace}-${var.env_name}-${var.service_name}${count.index + 1} Container Memory Utilization"
  alarm_actions       = [var.aws_sns_topic]
  ok_actions          = [var.aws_sns_topic]

  dimensions = {
    ServiceName = "${var.service_name}${count.index + 1}"
    ClusterName = "${var.namespace}-${var.env_name}-${var.service_name}-cluster"
  }
}
