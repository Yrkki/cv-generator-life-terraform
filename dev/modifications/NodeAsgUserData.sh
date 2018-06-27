#!/bin/sh
export EXTERNAL_LB='networkin-External-2CD0IZGKXO5X'
export DOCKER_FOR_IAAS_VERSION='18.04.0-ce-aws1'
export CHANNEL='edge'
export EDITION_ADDON='base'
export LOCAL_IP=$(wget -qO- http://169.254.169.254/latest/meta-data/local-ipv4)
export INSTANCE_TYPE=$(wget -qO- http://169.254.169.254/latest/meta-data/instance-type)
export NODE_AZ=$(wget -qO- http://169.254.169.254/latest/meta-data/placement/availability-zone/)
export NODE_REGION=$(echo $NODE_AZ | sed 's/.$//')
export ENABLE_CLOUDWATCH_LOGS='yes'
export AWS_REGION='eu-west-1'
export MANAGER_SECURITY_GROUP_ID='sg-052951d105ed32bf4'
export WORKER_SECURITY_GROUP_ID='sg-0501ebdb2c09dbda1'
export DYNAMODB_TABLE='networking-stack-dyndbtable'
export STACK_NAME='networking-stack'
export STACK_ID='arn:aws:cloudformation:eu-west-1:802807423235:stack/networking-stack/bd0616e0-7969-11e8-99b4-50a686333cfd'
export ACCOUNT_ID='802807423235'
export VPC_ID='vpc-03d8da261cb8aff51'
export SWARM_QUEUE='https://sqs.eu-west-1.amazonaws.com/802807423235/networking-stack-SwarmSQS-1JFMMAUQEZWF'
export CLEANUP_QUEUE='https://sqs.eu-west-1.amazonaws.com/802807423235/networking-stack-SwarmSQSCleanup-1PFBVT18OO43H'
export RUN_VACUUM='no'
export LOG_GROUP_NAME='networking-stack-lg'
export HAS_DDC='no'
export ENABLE_EFS='0'
export EFS_ID_REGULAR=''
export EFS_ID_MAXIO=''
export DOCKER_EXPERIMENTAL='true' 
export NODE_TYPE='worker'
export INSTANCE_NAME='NodeAsg'

mkdir -p /var/lib/docker/editions
echo "$EXTERNAL_LB" > /var/lib/docker/editions/lb_name
echo "# hostname : ELB_name" >> /var/lib/docker/editions/elb.config
echo "127.0.0.1: $EXTERNAL_LB" >> /var/lib/docker/editions/elb.config
echo "localhost: $EXTERNAL_LB" >> /var/lib/docker/editions/elb.config
echo "default: $EXTERNAL_LB" >> /var/lib/docker/editions/elb.config

echo '{"experimental": '$DOCKER_EXPERIMENTAL', "labels":["os=linux", "region='$NODE_REGION'", "availability_zone='$NODE_AZ'", "instance_type='$INSTANCE_TYPE'", "node_type='$NODE_TYPE'" ]' > /etc/docker/daemon.json

if [ $ENABLE_CLOUDWATCH_LOGS == 'yes' ] ; then
   echo ', "log-driver": "awslogs", "log-opts": {"awslogs-group": "'$LOG_GROUP_NAME'", "tag": "{{.Name}}-{{.ID}}" }}' >> /etc/docker/daemon.json
else
   echo ' }' >> /etc/docker/daemon.json
fi

chown -R docker /home/docker/
chgrp -R docker /home/docker/
rc-service docker restart
sleep 5

# init-aws
docker run --label com.docker.editions.system --log-driver=json-file --restart=no -d -e DYNAMODB_TABLE=$DYNAMODB_TABLE -e NODE_TYPE=$NODE_TYPE -e REGION=$AWS_REGION -e STACK_NAME=$STACK_NAME -e STACK_ID="$STACK_ID" -e ACCOUNT_ID=$ACCOUNT_ID -e INSTANCE_NAME=$INSTANCE_NAME -e DOCKER_FOR_IAAS_VERSION=$DOCKER_FOR_IAAS_VERSION -e EDITION_ADDON=$EDITION_ADDON -e HAS_DDC=$HAS_DDC -v /var/run/docker.sock:/var/run/docker.sock -v /var/log:/var/log docker4x/init-aws:$DOCKER_FOR_IAAS_VERSION

# guide-aws
docker run --label com.docker.editions.system --log-driver=json-file --log-opt max-size=50m --name=guide-aws --restart=always -d -e DYNAMODB_TABLE=$DYNAMODB_TABLE -e NODE_TYPE=$NODE_TYPE -e REGION=$AWS_REGION -e STACK_NAME=$STACK_NAME -e INSTANCE_NAME=$INSTANCE_NAME -e VPC_ID=$VPC_ID -e STACK_ID="$STACK_ID" -e ACCOUNT_ID=$ACCOUNT_ID -e SWARM_QUEUE="$SWARM_QUEUE" -e CLEANUP_QUEUE="$CLEANUP_QUEUE" -e RUN_VACUUM=$RUN_VACUUM -e DOCKER_FOR_IAAS_VERSION=$DOCKER_FOR_IAAS_VERSION -e EDITION_ADDON=$EDITION_ADDON -e HAS_DDC=$HAS_DDC -e CHANNEL=$CHANNEL -v /var/run/docker.sock:/var/run/docker.sock docker4x/guide-aws:$DOCKER_FOR_IAAS_VERSION

# cloudstor
docker plugin install --alias cloudstor:aws --grant-all-permissions docker4x/cloudstor:$DOCKER_FOR_IAAS_VERSION CLOUD_PLATFORM=AWS EFS_ID_REGULAR=$EFS_ID_REGULAR EFS_ID_MAXIO=$EFS_ID_MAXIO AWS_REGION=$AWS_REGION AWS_STACK_ID=$STACK_ID EFS_SUPPORTED=$ENABLE_EFS DEBUG=1
# Worker user data

# MODIFICATIONS START HERE!
