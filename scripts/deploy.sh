#!/bin/bash

# Variables
STACK_NAME="MainStack"
S3_BUCKET="developer-bucket-v1"
VPC_TEMPLATE="code/vpc.yaml"
IGW_TEMPLATE="code/igw.yaml"
SUBNET_TEMPLATE="code/subnet.yaml"
ROUTE_TABLE_TEMPLATE="code/rt.yaml"
SECURITY_GROUP_TEMPLATE="code/sg.yaml"
MAIN_TEMPLATE="code/main.yaml"
EC2_TEMPLATE="code/ec2.yaml"  # Add EC2 template

# Convert Unix path to Windows path (for AWS CLI compatibility in Git Bash)
PARENT_TEMPLATE="$(cygpath -w '/e/AwsLabProjects/Amazon-S3-VPC-Access/templates/main.yaml')"
CHILD_TEMPLATE_VPC="$(cygpath -w '/e/AwsLabProjects/Amazon-S3-VPC-Access/templates/vpc.yaml')"
CHILD_TEMPLATE_IGW="$(cygpath -w '/e/AwsLabProjects/Amazon-S3-VPC-Access/templates/igw.yaml')"
CHILD_TEMPLATE_SUBNET="$(cygpath -w '/e/AwsLabProjects/Amazon-S3-VPC-Access/templates/subnet.yaml')"
CHILD_TEMPLATE_RT="$(cygpath -w '/e/AwsLabProjects/Amazon-S3-VPC-Access/templates/rt.yaml')"
CHILD_TEMPLATE_SG="$(cygpath -w '/e/AwsLabProjects/Amazon-S3-VPC-Access/templates/sg.yaml')"
CHILD_TEMPLATE_EC2="$(cygpath -w '/e/AwsLabProjects/Amazon-S3-VPC-Access/templates/ec2.yaml')"  # Add EC2 template path

# Ensure AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it and configure your credentials."
    exit 1
fi

# Ensure template files exist
for FILE in "$CHILD_TEMPLATE_VPC" "$CHILD_TEMPLATE_IGW" "$CHILD_TEMPLATE_SUBNET" "$CHILD_TEMPLATE_RT" "$CHILD_TEMPLATE_SG" "$CHILD_TEMPLATE_EC2" "$PARENT_TEMPLATE"; do
    if [[ ! -f "$FILE" ]]; then
        echo "❌ ERROR: Template file not found at $FILE"
        exit 1
    fi
done

# Upload all CloudFormation templates to S3
echo "📤 Uploading templates to S3..."
aws s3 cp "$CHILD_TEMPLATE_VPC" s3://$S3_BUCKET/$VPC_TEMPLATE --acl private
aws s3 cp "$CHILD_TEMPLATE_IGW" s3://$S3_BUCKET/$IGW_TEMPLATE --acl private
aws s3 cp "$CHILD_TEMPLATE_SUBNET" s3://$S3_BUCKET/$SUBNET_TEMPLATE --acl private
aws s3 cp "$CHILD_TEMPLATE_RT" s3://$S3_BUCKET/$ROUTE_TABLE_TEMPLATE --acl private
aws s3 cp "$CHILD_TEMPLATE_SG" s3://$S3_BUCKET/$SECURITY_GROUP_TEMPLATE --acl private
aws s3 cp "$CHILD_TEMPLATE_EC2" s3://$S3_BUCKET/$EC2_TEMPLATE --acl private  # Upload EC2 template
aws s3 cp "$PARENT_TEMPLATE" s3://$S3_BUCKET/$MAIN_TEMPLATE --acl private

# Check if the parent stack exists
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].StackStatus" --output text 2>/dev/null)

if [[ "$STACK_STATUS" == "CREATE_COMPLETE" || "$STACK_STATUS" == "UPDATE_COMPLETE" ]]; then
    echo "🔄 Updating the existing stack: $STACK_NAME"
    aws cloudformation update-stack --stack-name $STACK_NAME \
        --template-body file://"$PARENT_TEMPLATE" \
        --capabilities CAPABILITY_NAMED_IAM
    aws cloudformation wait stack-update-complete --stack-name $STACK_NAME
elif [[ "$STACK_STATUS" == "ROLLBACK_COMPLETE" || "$STACK_STATUS" == "DELETE_COMPLETE" || -z "$STACK_STATUS" ]]; then
    echo "🚀 Creating a new stack: $STACK_NAME"
    aws cloudformation create-stack --stack-name $STACK_NAME \
        --template-body file://"$PARENT_TEMPLATE" \
        --capabilities CAPABILITY_NAMED_IAM
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME
else
    echo "❌ ERROR: Stack $STACK_NAME is in an unexpected state: $STACK_STATUS"
    exit 1
fi

# Retrieve Resource IDs
VPC_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='VPCId'].OutputValue" --output text)
IGW_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='InternetGatewayId'].OutputValue" --output text)
PUBLIC_SUBNET_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PublicSubnetId'].OutputValue" --output text)
PRIVATE_SUBNET_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PrivateSubnetId'].OutputValue" --output text)
PUBLIC_RT_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PublicRouteTableId'].OutputValue" --output text)
PRIVATE_RT_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PrivateRouteTableId'].OutputValue" --output text)
BASTION_SG_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='BastionSecurityGroupId'].OutputValue" --output text)
PRIVATE_EC2_SG_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PrivateEC2SecurityGroupId'].OutputValue" --output text)
BASTION_INSTANCE_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='BastionInstanceId'].OutputValue" --output text)
PRIVATE_EC2_INSTANCE_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PrivateEC2InstanceId'].OutputValue" --output text)

# Wait for EC2 instances to be running (both Bastion and Private EC2)
while true; do
  # Ensure the EC2 Instance ID is not empty or "None"
  if [[ -z "$BASTION_INSTANCE_ID" || "$BASTION_INSTANCE_ID" == "None" ]]; then
    echo "❌ ERROR: Bastion EC2 Instance ID not found."
    exit 1
  fi
  if [[ -z "$PRIVATE_EC2_INSTANCE_ID" || "$PRIVATE_EC2_INSTANCE_ID" == "None" ]]; then
    echo "❌ ERROR: Private EC2 Instance ID not found."
    exit 1
  fi
  
  BASTION_STATE=$(aws ec2 describe-instances --instance-ids "$BASTION_INSTANCE_ID" --query "Reservations[0].Instances[0].State.Name" --output text)
  PRIVATE_EC2_STATE=$(aws ec2 describe-instances --instance-ids "$PRIVATE_EC2_INSTANCE_ID" --query "Reservations[0].Instances[0].State.Name" --output text)

  if [[ "$BASTION_STATE" == "running" && "$PRIVATE_EC2_STATE" == "running" ]]; then
    echo "✅ Both Bastion and Private EC2 instances are running."
    break
  else
    echo "⏳ Waiting for EC2 instances to be running..."
    sleep 30  # Wait 30 seconds before checking again
  fi
done
