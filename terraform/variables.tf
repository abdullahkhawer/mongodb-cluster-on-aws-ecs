variable "account_id" {
  description = "AWS account id"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "namespace" {
  description = "Name of project"
  type        = string
}

variable "env_name" {
  description = "Name of environment"
  type        = string
}

variable "service_name" {
  description = "Name of service"
  type        = string
  default     = "mongodb"
}

variable "vpc_id" {
  description = "ID of VPC"
  type        = string
}

variable "volume_type" {
  description = "Volume type"
  type        = string
  default     = "gp3"
}

variable "volume_size" {
  description = "Volume size"
  type        = number
}

variable "volume_iops" {
  description = "Volume IOPS"
  type        = number
}

variable "volume_encrypted" {
  description = "Volume encryption"
  type        = string
  default     = false
}

variable "volume_encryption_key" {
  description = "Volume encryption KMS key"
  type        = string
  default     = null
}

variable "cpu" {
  description = "ECS Service CPU for MongoDB"
  type        = number
}

variable "memory" {
  description = "ECS Service Memory for MongoDB"
  type        = number
}

variable "instance_type" {
  description = "Instance type"
  type        = string
}

variable "image" {
  description = "Docker image URL"
  type        = string
}

variable "hosted_zone_name" {
  description = "Name of hosted zone on Route53"
  type        = string
}

variable "ec2_key_pair_name" {
  description = "Name of key pair to be used by EC2 instance"
  type        = string
}

variable "number_of_instances" {
  description = "Number of MongoDB instances to be created."
  type        = number
  default     = 1
  validation {
    condition     = contains([1, 2, 3], var.number_of_instances)
    error_message = "Invalid number of instances. Allowed values: [1, 2, 3]."
  }
}

variable "backup_enabled" {
  description = "Boolean to decide whether to take MongoDB backup or not"
  type        = string
  default     = false
}

variable "private_subnet_tag_name" {
  description = "Tag name to filter private subnets for selection"
  type        = string
  default     = "*private*"
}

variable "aws_sns_topic" {
  description = "SNS topic arn"
  type        = string
}

variable "alarm_treat_missing_data" {
  description = "Missing data on alarms"
  type        = string
  default     = "ignore"
}

variable "mongodb_backup_databases" {
  description = "List of MongoDB databases and collections eligible for backup in the following format: dbname:[ALL|collection-name;collection-name;...],..."
  type        = string
  default     = "admin:ALL"
}

variable "monitoring_enabled" {
  description = "Boolean to decide whether to enable monitoring for MongoDB or not"
  type        = string
  default     = false
}
