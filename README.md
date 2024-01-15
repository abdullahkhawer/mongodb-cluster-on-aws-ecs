# MongoDB cluster on AWS ECS

- Founder: Abdullah Khawer (LinkedIn: https://www.linkedin.com/in/abdullah-khawer/)

## Introduction

A Terraform module developed to quickly deploy a secure, persistent, highly available, self healing, efficient and cost effective single-node or multi-node MongoDB NoSQL document database cluster on AWS ECS cluster as there is no managed service available for MongoDB on AWS with such features.

## Key Highlights

- A single-node or multi-node MongoDB cluster under AWS Auto Scaling group to launch multiple MongoDB nodes as replicas to make it highly available, efficient and self healing with a help of bootstrapping script with some customizations.
- Using AWS ECS service registry with awsvpc as network mode instead of AWS ELB to save cost on networking side and make it more secure. AWS ECS task IPs are updated by the bootstrapping script on an AWS Route 53 hosted zone.
- Persistent and encrypted AWS EBS volumes of type gp3 using rexray/ebs Docker plugin so the data stays secure and reliable.
- AWS S3 bucket for backups storage for disaster recovery along with lifecycle rules for data archival and deletion.
- Custom backup and restore scripts for data migration and disaster recovery capabilities available on each AWS EC2 instance due to a bootstrapping script.
- Each AWS EC2 instance is configured with various customizations like pre-installed wget, unzip, awscli, Docker, ECS agent, MongoDB, Mongosh, MongoDB database tools, key file for MongoDB Cluster, custom agent for AWS EBS volumes disk usage monitoring and cronjobs to take a backup at 03:00 AM daily and to send disk usage metrics to AWS CloudWatch at every minute.
- Each AWS EC2 instance is configured with soft rlimits and ulimits defined and transparent huge pages disabled to make MongoDB database more efficient.

## Usage Notes

### Prerequisites

Following are the resources that should exist already before starting the deployment:

- 1 secure parameter named `/docker/[ENVIRONMENT_NAME]/MONGODB_USERNAME` under **AWS SSM Parameter Store** having username of MongoDB cluster.
- 1 secure parameter named `/docker/[ENVIRONMENT_NAME]/MONGODB_PASSWORD` under **AWS SSM Parameter Store** having password of MongoDB cluster.
- 1 secure parameter named `/docker/[ENVIRONMENT_NAME]/MONGODB_KEYFILE` under **AWS SSM Parameter Store** having contents of a keyfile created locally with the following commands for MongoDB cluster:
    - `openssl rand -base64 756 > mongodb.key`
    - `chmod 400 mongodb.key`
- 1 key pair named `[PROJECT]-[ENVIRONMENT_NAME]-mongodb` under **AWS EC2 Key Pairs**.
- 1 private hosted zone under **AWS Route53** with any working domain.
- 1 vpc under **AWS VPC** having at least 1 private subnet or ideally, 3 private and 3 public subnets with name tags (e.g., Private-1-Subnet, Private-2-Subnet, etc).

## Deployment Instructions

Simply deploy it from the terraform directory directly or either as a Terraform module by specifying the desired values for the variables. You can check `terraform-usage-example.tf` file as an example.

## Post Deployment Replica Set Configuration

Once the deployment is done, log into the MongoDB cluster via its 1st AWS EC2 instance node using AWS SSM Session Manager using the following command: `mongosh "mongodb://[USERNAME]:[PASSWORD]@mongodb1.[ENVIRONMENT_NAME]-local:27017/admin?&retryWrites=false"`

Then initiate the replica set using the following command:

```
rs.initiate({
_id: "rs0",
members: [
    { _id: 0, host: "mongodb1.[ENVIRONMENT_NAME]-local:27017" },
    { _id: 1, host: "mongodb2.[ENVIRONMENT_NAME]-local:27017" },
    { _id: 2, host: "mongodb3.[ENVIRONMENT_NAME]-local:27017" }
]
})
```

You can now connect to the replica set using the following command: `mongosh "mongodb://[USERNAME]:[PASSWORD]@mongodb1.[ENVIRONMENT_NAME]-local:27017,mongodb2.[ENVIRONMENT_NAME]-local:27017,mongodb3.[ENVIRONMENT_NAME]-local:27017/admin?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=true"`

*Note: The sample commands in the above example assumes that the cluster has 3 nodes.*

## Replica Set Recovery

If you lost the replica set, you can reconfigure it using the following commands:

```
rs.reconfig({
_id: "rs0",
members: [
    { _id: 0, host: "mongodb1.stage-local:27017" }
]
}, {"force":true})

rs.add({ _id: 1, host: "mongodb2.stage-local:27017" })

rs.add({ _id: 2, host: "mongodb3.stage-local:27017" })
```

*Note: The sample commands in the above example assumes that the cluster has 3 nodes.*

#### Warning: You will be billed for the AWS resources created by this framework.

##### Any contributions, improvements and suggestions will be highly appreciated. 😊
