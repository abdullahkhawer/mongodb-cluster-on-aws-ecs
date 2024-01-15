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