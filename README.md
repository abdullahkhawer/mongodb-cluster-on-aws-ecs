# MongoDB Cluster on AWS ECS - Terraform Module

- Founder: Abdullah Khawer (LinkedIn: https://www.linkedin.com/in/abdullah-khawer/)

## Introduction

A Terraform module to quickly deploy a secure, persistent, highly available, self healing, efficient, cost effective and self managed single-node or multi-node MongoDB NoSQL document database cluster on AWS ECS cluster with monitoring and alerting enabled.

## Key Highlights

- A self managed single-node (1 node) or multi-node (2 or 3 nodes) MongoDB cluster under AWS Auto Scaling group to launch multiple MongoDB nodes as replicas to make it highly available, efficient and self healing with a help of bootstrapping script with some customizations.
- Using AWS Route 53 private hosted zone for AWS ECS services with `awsvpc` as the network mode instead of AWS ELB to save cost on networking side and make it more secure. AWS ECS services' task IPs are updated on the AWS Route 53 private hosted zone by the bootstrapping script that runs on each AWS EC2 instance node as user data.
- Persistent and encrypted AWS EBS volumes of type gp3 using rexray/ebs Docker plugin so the data stays secure and reliable.
- AWS S3 bucket for backups storage for disaster recovery along with a lifecycle rule with Intelligent-Tiering as storage class for objects to save data storage cost.
- Custom backup and restore scripts for data migration and disaster recovery capabilities are available on each AWS EC2 instance node by the bootstrapping script running as user data.
- Each AWS EC2 instance node is configured with various customizations like pre-installed wget, unzip, awscli, Docker, ECS agent, MongoDB, Mongosh, MongoDB database tools, key file for MongoDB Cluster, custom agent for AWS EBS volumes disk usage monitoring and cronjobs to take a backup at 03:00 AM UTC daily and to send disk usage metrics to AWS CloudWatch at every minute.
- Each AWS EC2 instance node is configured with soft rlimits and ulimits defined and transparent huge pages disabled to make MongoDB database more efficient.
- AWS CloudWatch alarms to send alerts when the utilization of CPU, Memory and Disk Space goes beyond 85%.

## Usage Notes

### Prerequisites

Following are the resources that should exist already before starting the deployment:

- 1 secure parameter named `/docker/[ENVIRONMENT_NAME]/MONGODB_USERNAME` under **AWS SSM Parameter Store** having username of MongoDB cluster.
- 1 secure parameter named `/docker/[ENVIRONMENT_NAME]/MONGODB_PASSWORD` under **AWS SSM Parameter Store** having password of MongoDB cluster.
- 1 secure parameter named `/docker/[ENVIRONMENT_NAME]/MONGODB_KEYFILE` under **AWS SSM Parameter Store** having contents of a keyfile created locally with the following commands for MongoDB cluster:
    - `openssl rand -base64 756 > mongodb.key`
    - `chmod 400 mongodb.key`
- 1 key pair named `[PROJECT]-[ENVIRONMENT_NAME]-mongodb` under **AWS EC2 Key Pairs**.
- 1 private hosted zone under **AWS Route53** with a working domain.
- 1 vpc under **AWS VPC** having at least 1, 2 or 3 private subnets having a name tag on each (e.g., Private-1-Subnet, Private-2-Subnet, etc).
- 1 topic under **AWS SNS** to send notifications via AWS CloudWatch alarms.

## Deployment Instructions

Simply deploy it from the terraform directory directly or either as a Terraform module by specifying the desired values for the variables. You can check `terraform-usage-example.tf` file as an example.

## Post Deployment Replica Set Configuration

Once the deployment is done, log into the MongoDB cluster via its 1st AWS EC2 instance node using AWS SSM Session Manager using the following command after replacing `[USERNAME]`, `[PASSWORD]`, `[ENVIRONMENT_NAME]` and `[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]` in it: `mongosh "mongodb://[USERNAME]:[PASSWORD]@[ENVIRONMENT_NAME]-mongodb1.[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]:27017/admin?&retryWrites=false"`

Then initiate the replica set using the following command after replacing `[ENVIRONMENT_NAME]` and `[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]` in it:

```
rs.initiate({
_id: "rs0",
members: [
    { _id: 0, host: "[ENVIRONMENT_NAME]-mongodb1.[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]:27017" },
    { _id: 1, host: "[ENVIRONMENT_NAME]-mongodb2.[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]:27017" },
    { _id: 2, host: "[ENVIRONMENT_NAME]-mongodb3.[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]:27017" }
]
})
```

You can now connect to the replica set using the following command after replacing `[USERNAME]`, `[PASSWORD]`, `[ENVIRONMENT_NAME]` and `[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]` in it: `mongosh "mongodb://[USERNAME]:[PASSWORD]@[ENVIRONMENT_NAME]-mongodb1.[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]:27017,[ENVIRONMENT_NAME]-mongodb2.[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]:27017,[ENVIRONMENT_NAME]-mongodb3.[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]:27017/admin?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=true"`

*Note: The sample commands in the above example assumes that the cluster has 3 nodes.*

## Replica Set Recovery

If you lost the replica set, you can reconfigure it using the following commands after replacing `[ENVIRONMENT_NAME]` and `[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]` in them:

```
rs.reconfig({
_id: "rs0",
members: [
    { _id: 0, host: "[ENVIRONMENT_NAME]-mongodb1.[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]:27017" }
]
}, {"force":true})

rs.add({ _id: 1, host: "[ENVIRONMENT_NAME]-mongodb2.[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]:27017" })

rs.add({ _id: 2, host: "[ENVIRONMENT_NAME]-mongodb3.[AWS_ROUTE_53_PRIVATE_HOSTED_ZONE_NAME]:27017" })
```

*Note: The sample commands in the above example assumes that the cluster has 3 nodes.*

#### Warning: You will be billed for the AWS resources created by this framework.

##### Any contributions, improvements and suggestions will be highly appreciated. 😊
