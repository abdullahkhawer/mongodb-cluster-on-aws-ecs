# Note: dummy value is something that has to be replaced even for this example to work.

module "mongodb-cluster-on-aws-ecs" {
  source = "./terraform"

  account_id              = "012345678910" # dummy value
  aws_region              = "eu-west-1"    # Europe (Ireland)
  namespace               = "project"      # dummy value
  env_name                = "dev"
  service_name            = "mongodb"
  vpc_id                  = "vpc-012345678910abcde" # dummy value
  volume_type             = "gp3"
  volume_size             = 20
  volume_iops             = 3000
  volume_encrypted        = true
  volume_encryption_key   = "arn:aws:kms:eu-west-1:012345678910:key/0123abcd-01ab-01ab-0123-012345abcdef" # dummy value
  cpu                     = 1648
  memory                  = 1854
  instance_type           = "t3.small"
  image                   = "docker.io/mongo:5.0.6"
  hosted_zone_name        = "project.net"         # dummy value
  ec2_key_pair_name       = "project-dev-mongodb" # dummy value
  number_of_instances     = 3                     # Minimum 1, Maximum 3
  private_subnet_tag_name = "Private-1*"          # dummy value

  # If you want to enable disk usage monitoring
  monitoring_enabled       = true
  alarm_treat_missing_data = "ignore"
  aws_sns_topic            = "arn:aws:sns:eu-west-1:012345678910:AWS_SNS_TOPIC_NAME"

  # If you want to enable backups
  backup_enabled           = true
  mongodb_backup_databases = "admin:ALL" # dummy value
}
