# Changelog

All notable changes to this project will be documented in this file.


## [1.1.0] - 2024-01-23

[1.1.0]: https://github.com/abdullahkhawer/mongodb-cluster-on-aws-ecs/releases/tag/v1.1.0

### Features

- Update code to set the threshold for CPU, memory, and Disk space utilization to 85%, create locals to define AWS VPC private subnets along with their length, select the correct AWS VPC private subnet ID even if there are fewer subnets than the number of AWS EC2 instances, select the correct private AWS Route 53 hosted zone if both public and private exist with the same name/domain, set correct AWS ECS cluster name under dimensions for AWS CloudWatch metric alarms, fix Terraform code with respect to the AWS Terraform provider v4.65.0, update backups AWS S3 bucket's lifecycle policy rules to set a rule for INTELLIGENT_TIERING, add code to wait for the first AWS EC2 instance to be running and complete status checks, refactor the whole Terraform code and update the README accordingly.

### Miscellaneous Tasks

- Add mongodb.key in .gitignore file.

## [1.0.0] - 2024-01-15

[1.0.0]: https://github.com/abdullahkhawer/mongodb-cluster-on-aws-ecs/releases/tag/v1.0.0

### Features

- [**breaking**] Develop a Terraform Module for MongoDB to run it on AWS ECS to create a multi-node MongoDB cluster under AWS Auto Scaling group to launch multiple MongoDB nodes as replicas with AWS ECS service registry using awsvpc as network mode, persistent and encrypted AWS EBS volumes of type gp3, AWS S3 bucket for backups storage along with lifecycle rules for data archival and deletion and User Data script to prepare an AWS EC2 instance by setting up wget, unzip, awscli, Docker, ECS agent, rexray/ebs Docker plugin, MongoDB, Mongosh, MongoDB database tools, MongoDB backup and restore scripts, key file for MongoDB Cluster, custom agent for AWS EBS volumes disk usage monitoring, cronjobs for backup at 03:00 AM daily and disk usage monitoring at every minute, soft rlimits and ulimits and disabling transparent huge pages on it and also creating DNS record in AWS Route 53 hosted zone for it. Also, update README accordingly.
