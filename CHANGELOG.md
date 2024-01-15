# Changelog

All notable changes to this project will be documented in this file.


## [1.0.0] - 2024-01-15

[1.0.0]: https://github.com/abdullahkhawer/mongodb-cluster-on-aws-ecs/releases/tag/v1.0.0

### Features

- [**breaking**] Develop a Terraform Module for MongoDB to run it on AWS ECS to create a multi-node MongoDB cluster under AWS Auto Scaling group to launch multiple MongoDB nodes as replicas with AWS ECS service registry using awsvpc as network mode, persistent and encrypted AWS EBS volumes of type gp3, AWS S3 bucket for backups storage along with lifecycle rules for data archival and deletion and User Data script to prepare an AWS EC2 instance by setting up wget, unzip, awscli, Docker, ECS agent, rexray/ebs Docker plugin, MongoDB, Mongosh, MongoDB database tools, MongoDB backup and restore scripts, key file for MongoDB Cluster, custom agent for AWS EBS volumes disk usage monitoring, cronjobs for backup at 03:00 AM daily and disk usage monitoring at every minute, soft rlimits and ulimits and disabling transparent huge pages on it and also creating DNS record in AWS Route 53 hosted zone for it. Also, update README accordingly.
