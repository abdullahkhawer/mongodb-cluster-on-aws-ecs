#! /bin/bash
set -x

# Install wget, unzip and awscli
yum install -y wget
yum install -y unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
/usr/local/bin/aws --version

echo "Installed wget, unzip and awscli"

# Increase soft rlimits
[ -e /etc/security/limits.conf ] && rm -f /etc/security/limits.conf
touch /etc/security/limits.conf

cat <<'EOT' >> /etc/security/limits.conf
# /etc/security/limits.conf
"* soft nofile 512000"
"* hard nofile 512000"
"* soft nproc 512000"
"* hard nproc 512000"
EOT

[ -e /etc/security/limits.d/90-nproc.conf ] && rm -f /etc/security/limits.d/90-nproc.conf
touch /etc/security/limits.d/90-nproc.conf

cat <<'EOT' >> /etc/security/limits.d/90-nproc.conf
# /etc/security/limits.d/90-nproc.conf
"* soft nproc 512000"
"* hard nproc 512000"
EOT

[ -e /etc/security/limits.d/90-nofile.conf ] && rm -f /etc/security/limits.d/90-nofile.conf
touch /etc/security/limits.d/90-nofile.conf

cat <<'EOT' >> /etc/security/limits.d/90-nofile.conf
# /etc/security/limits.d/90-nofile.conf
"* soft nofile 512000"
"* hard nofile 512000"
EOT

[ -e /etc/sysconfig/docker ] && rm -f /etc/sysconfig/docker
touch /etc/sysconfig/docker

cat <<'EOT' >> /etc/sysconfig/docker
# /etc/sysconfig/docker
# The max number of open files for the daemon itself, and all
# running containers.  The default value of 1048576 mirrors the value
# used by the systemd service unit.
DAEMON_MAXFILES=1048576

# Additional startup options for the Docker daemon, for example:
# OPTIONS="--ip-forward=true --iptables=true"
# By default we limit the number of open files per container
OPTIONS="--default-ulimit nofile=512000:512000 --default-ulimit nproc=512000:512000"

# How many seconds the sysvinit script waits for the pidfile to appear
# when starting the daemon.
DAEMON_PIDFILE_TIMEOUT=10
EOT

echo "Increased soft rlimits/ulimits"

# Disable transparent huge pages
[ -e /etc/init.d/disable-transparent-hugepages ] && rm -f /etc/init.d/disable-transparent-hugepages
touch /etc/init.d/disable-transparent-hugepages

cat <<'EOT' >> /etc/init.d/disable-transparent-hugepages
#!/bin/bash
### BEGIN INIT INFO
# Provides:          disable-transparent-hugepages
# Required-Start:    $local_fs
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Disable transparent huge pages
# Description:       Disable transparent huge pages to improve MongoDB database performance.
### END INIT INFO

echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled
echo 'never' > /sys/kernel/mm/transparent_hugepage/defrag
EOT

chmod 755 /etc/init.d/disable-transparent-hugepages

/etc/init.d/disable-transparent-hugepages start

chkconfig --add disable-transparent-hugepages

echo "Disabled transparent huge pages"

# Create DNS record in AWS Route 53 for this instance
HOST_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4);

/usr/local/bin/aws route53 change-resource-record-sets \
  --hosted-zone-id ${HOSTED_ZONE_ID} \
  --change-batch \
'{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${DNS_NAME}",
        "Type": "A",
        "TTL": 30,
        "ResourceRecords": [
          {
            "Value": "'"$HOST_IP"'"
          }
        ]
      }
    }
  ]
}'

echo "Created DNS record in AWS Route 53 for this instance"

# Configure and start ECS agent
cat <<'EOF' >> /etc/ecs/ecs.config
ECS_CLUSTER=${ECS_CLUSTER}
ECS_INSTANCE_ATTRIBUTES=${ECS_INSTANCE_ATTRIBUTES}
EOF

sed -i '/After=cloud-final.service/d' /usr/lib/systemd/system/ecs.service

systemctl daemon-reload

# Verify that the agent is running
until curl -s http://localhost:51678/v1/metadata
do
	sleep 1
done

echo "Configured and started ECS agent"

# Install the Docker volume plugin
docker plugin install rexray/ebs REXRAY_PREEMPT=true EBS_REGION=${AWS_REGION} --grant-all-permissions

echo "Installed rexray/ebs Docker plugin"

systemctl restart docker
systemctl restart ecs

echo "Restarted Docker and ECS agent"

# Install Mongosh
cat <<'EOF' >> /etc/yum.repos.d/mongodb-org-5.0.repo
[mongodb-org-5.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/5.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-5.0.asc
EOF

yum install -y mongodb-mongosh

echo "Installed Mongosh"

# Install MongoDB database tools
wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-amazon2-x86_64-100.5.1.rpm
yum install -y mongodb-database-tools-amazon2-x86_64-100.5.1.rpm

echo "Installed MongoDB database tools"

# Copy key file for MongoDB Cluster
MONGODB_KEYFILE=$(/usr/local/bin/aws ssm get-parameter --name ${MONGODB_KEYFILE_PARAMETER_NAME} --with-decryption --output text --query Parameter.Value)
mkdir -p /usr/bin/keys
echo "$MONGODB_KEYFILE" > /usr/bin/keys/mongodb.key
chmod 400 /usr/bin/keys/mongodb.key
chown 999:999 /usr/bin/keys/mongodb.key

echo "Copied key file for MongoDB Cluster"

# Install MongoDB backup script
cat <<'EOF' >> /usr/bin/mongo-backup.sh
#!/bin/bash
set -e

# Create variables
TIMESTAMP=`date +%F-%H-%M`
BACKUP_S3_BUCKET_NAME=${BACKUP_S3_BUCKET_NAME}
MONGODB_HOST=${DNS_NAME}
MONGODB_USER=$(/usr/local/bin/aws ssm get-parameter --name ${MONGODB_USER_PARAMETER_NAME} --with-decryption --output text --query Parameter.Value)
MONGODB_PASSWORD=$(/usr/local/bin/aws ssm get-parameter --name ${MONGODB_PASSWORD_PARAMETER_NAME} --with-decryption --output text --query Parameter.Value)
MONGO_DATABASES=${MONGO_DATABASES}

# Create MongoDB databases backup
IFS=","
for DB in $MONGO_DATABASES
do 
    IFS=":" && Array=($DB)
    DB_NAME=$${Array[0]}
    COLLECTIONS=$${Array[1]}
    if [ $COLLECTIONS = "ALL" ]
    then
        mongodump --username $MONGODB_USER --password $MONGODB_PASSWORD --authenticationDatabase "admin" --db=$DB_NAME -v mongodb://$MONGODB_HOST:27017
    else
        IFS=";"
        for COLLECTION in $COLLECTIONS
        do
            mongodump --username $MONGODB_USER --password $MONGODB_PASSWORD --authenticationDatabase "admin" --db=$DB_NAME --collection=$COLLECTION -v mongodb://$MONGODB_HOST:27017
        done
    fi
done

# Compress backup with timestamp
tar vcf mongodb-$TIMESTAMP.tar dump

# Upload to S3
/usr/local/bin/aws s3 cp mongodb-$TIMESTAMP.tar s3://$BACKUP_S3_BUCKET_NAME/backups/mongodb-$TIMESTAMP.tar

# Delete local files
rm -rf dump
rm -rf mongodb-*

# Print success message
echo "Data in MongoDB cluster is backed up and stored on S3 successfully."
EOF

echo "Installed MongoDB backup script"

# Install MongoDB restore script
cat <<'EOF' >> /usr/bin/mongo-restore.sh
#!/bin/bash
set -e

if [ -z "$1" ]; then echo "ERROR: Backup File Name from S3 is Empty." && exit 0; fi

# Create variables
BACKUP_S3_BUCKET_NAME=${BACKUP_S3_BUCKET_NAME}
MONGODB_HOST=${DNS_NAME}
MONGODB_USER=$(/usr/local/bin/aws ssm get-parameter --name ${MONGODB_USER_PARAMETER_NAME} --with-decryption --output text --query Parameter.Value)
MONGODB_PASSWORD=$(/usr/local/bin/aws ssm get-parameter --name ${MONGODB_PASSWORD_PARAMETER_NAME} --with-decryption --output text --query Parameter.Value)

# Download compressed backup json file from S3
/usr/local/bin/aws s3 cp s3://$BACKUP_S3_BUCKET_NAME/backups/$1 mongodb-backup.tar

# Decompress backup json file
tar -xf mongodb-backup.tar dump

# Restore etcd from backup json file
mongorestore --host=$MONGODB_HOST:27017 --username=$MONGODB_USER --password=$MONGODB_PASSWORD --authenticationDatabase "admin" -v ./dump

# Delete local files
rm -rf dump
rm -rf mongodb-backup.tar

# Print success message
echo "Data in MongoDB cluster is restored from S3 successfully."
EOF

echo "Installed MongoDB restore script"

# Enable cron for MongoDB backup script
if [ "${ENABLE_BACKUP}" = "YES" ]
then
  # Enable cron
  crontab -l > tempfile
  echo "0 3 * * * /bin/bash /usr/bin/mongo-backup.sh" >> tempfile
  crontab tempfile
  rm tempfile

  echo "Enabled cron for MongoDB backup script"
fi

# Install custom agent for EBS disk usage monitoring
cat <<'EOF' >> /usr/bin/send-ebs-disk-usage-on-cloudwatch.sh
#!/bin/bash
set -e

ASG_NAME=${ASG_NAME}
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
COUNT=1

df -h --print-type --type="ext4" --type="xfs" | grep "/" | while read LINE
do
  DATA=$(echo ${LINE} | awk '{print $1, $2, $6, $7}')

  IFS=" " && Array=($DATA)

  DEVICE_NAME=$${Array[0]}
  DEVICE_NAME_TRIMMED="$${DEVICE_NAME//'/'}"
  FILE_SYSTEM=$${Array[1]}
  DISK_USED=$${Array[2]}
  DISK_USED="$${DISK_USED//%}"
  MOUNT_PATH=$${Array[3]}

  if [ -e "/usr/bin/cw-alarm-$${COUNT}.file" ]
  then
    /usr/local/bin/aws cloudwatch put-metric-data \
      --metric-name disk_used_percent \
      --namespace CustomAgent \
      --unit Percent \
      --value "$DISK_USED" \
      --dimensions \
        AutoScalingGroupName="$ASG_NAME",InstanceID="$INSTANCE_ID",device="$DEVICE_NAME",fstype="$FILE_SYSTEM",path="$MOUNT_PATH"
  else
    /usr/local/bin/aws cloudwatch put-metric-alarm \
      --alarm-name "${ALARM_NAME_PREFIX}-ebs-volume-$${COUNT}-disk-utilization" \
      --comparison-operator GreaterThanThreshold \
      --evaluation-periods 1 \
      --metric-name disk_used_percent \
      --namespace CustomAgent \
      --period 60 \
      --statistic Maximum \
      --threshold 85 \
      --datapoints-to-alarm 1 \
      --treat-missing-data "${ALARM_TREAT_MISSING_DATA}" \
      --alarm-description "${ALARM_NAME_PREFIX} EBS Volume Disk Utilization" \
      --alarm-actions "${ALARM_SNS_TOPIC}" \
      --ok-actions "${ALARM_SNS_TOPIC}" \
      --dimensions \
        Name="AutoScalingGroupName",Value="$ASG_NAME" \
        Name="InstanceID",Value="$INSTANCE_ID" \
        Name="device",Value="$DEVICE_NAME" \
        Name="fstype",Value="$FILE_SYSTEM" \
        Name="path",Value="$MOUNT_PATH"

    touch "/usr/bin/cw-alarm-$${COUNT}.file"
  fi

  COUNT=$((COUNT+1))
done
EOF

echo "Installed custom agent for EBS disk usage monitoring"

# Enable cron for custom agent for EBS disk usage monitoring
if [ "${ENABLE_MONITORING}" = "YES" ]
then
  # Enable cron
  crontab -l > tempfile
  echo "* * * * * /bin/bash /usr/bin/send-ebs-disk-usage-on-cloudwatch.sh" >> tempfile
  crontab tempfile
  rm tempfile

  echo "Enabled custom agent for EBS disk usage monitoring"
fi
