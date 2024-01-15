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