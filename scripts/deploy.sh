#!/bin/bash

# Variables
STACK_NAME="MainStack"
S3_BUCKET="developer-bucket-v1"
AWS_REGION="eu-west-2"  # Change to your region if needed

# Template paths
TEMPLATES_DIR="/e/AwsLabProjects/Amazon-S3-VPC-Access/templates"
S3_PREFIX="code"

# Convert Unix path to Windows path for AWS CLI in Git Bash
convert_path() {
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    echo "$(cygpath -w "$1")"
  else
    echo "$1"
  fi
}

# Template files
declare -A TEMPLATE_PATHS=(
  ["VPC"]="vpc.yaml"
  ["IGW"]="igw.yaml"
  ["SUBNET"]="subnet.yaml"
  ["ROUTE_TABLE"]="rt.yaml"
  ["SECURITY_GROUP"]="sg.yaml"
  ["EC2"]="ec2.yaml"
  ["S3_ENDPOINT"]="s3endpoint.yaml"
  ["MAIN"]="main.yaml"
)

# Ensure AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it and configure your credentials."
    exit 1
fi

# Ensure all template files exist
echo "🔍 Checking for missing template files..."
for KEY in "${!TEMPLATE_PATHS[@]}"; do
  LOCAL_PATH="$(convert_path "$TEMPLATES_DIR/${TEMPLATE_PATHS[$KEY]}")"
  if [[ ! -f "$LOCAL_PATH" ]]; then
    echo "❌ ERROR: Template file not found at $LOCAL_PATH"
    exit 1
  fi
done

# Upload all CloudFormation templates to S3
echo "📤 Uploading CloudFormation templates to S3..."
for KEY in "${!TEMPLATE_PATHS[@]}"; do
  LOCAL_PATH="$(convert_path "$TEMPLATES_DIR/${TEMPLATE_PATHS[$KEY]}")"
  S3_PATH="s3://$S3_BUCKET/$S3_PREFIX/${TEMPLATE_PATHS[$KEY]}"
  
  echo "🚀 Uploading $LOCAL_PATH -> $S3_PATH"
  aws s3 cp "$LOCAL_PATH" "$S3_PATH" --acl private --region $AWS_REGION
done
echo "✅ All templates uploaded successfully!"

# Check if the parent stack exists
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].StackStatus" --output text --region $AWS_REGION 2>/dev/null)

if [[ "$STACK_STATUS" == "CREATE_COMPLETE" || "$STACK_STATUS" == "UPDATE_COMPLETE" ]]; then
    echo "🔄 Updating the existing CloudFormation stack: $STACK_NAME"
    aws cloudformation update-stack --stack-name $STACK_NAME \
        --template-url "https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/$S3_PREFIX/${TEMPLATE_PATHS["MAIN"]}" \
        --capabilities CAPABILITY_NAMED_IAM --region $AWS_REGION
    aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $AWS_REGION
elif [[ "$STACK_STATUS" == "ROLLBACK_COMPLETE" || "$STACK_STATUS" == "DELETE_COMPLETE" || -z "$STACK_STATUS" ]]; then
    echo "🚀 Creating a new CloudFormation stack with rollback disabled: $STACK_NAME"
    aws cloudformation create-stack --stack-name $STACK_NAME \
        --template-url "https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/$S3_PREFIX/${TEMPLATE_PATHS["MAIN"]}" \
        --capabilities CAPABILITY_NAMED_IAM --region $AWS_REGION \
        --disable-rollback  # 🚀 This prevents deletion on failure
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $AWS_REGION
else
    echo "❌ ERROR: Stack $STACK_NAME is in an unexpected state: $STACK_STATUS"
    exit 1
fi

# Retrieve Resource IDs
declare -A RESOURCE_IDS=(
  ["VPC"]="VPCId"
  ["IGW"]="InternetGatewayId"
  ["PUBLIC_SUBNET"]="PublicSubnetId"
  ["PRIVATE_SUBNET"]="PrivateSubnetId"
  ["PUBLIC_RT"]="PublicRouteTableId"
  ["PRIVATE_RT"]="PrivateRouteTableId"
  ["BASTION_SG"]="BastionSecurityGroupId"
  ["PRIVATE_EC2_SG"]="PrivateEC2SecurityGroupId"
  ["BASTION_INSTANCE"]="BastionInstanceId"
  ["PRIVATE_EC2_INSTANCE"]="PrivateEC2InstanceId"
  ["S3_ENDPOINT"]="S3EndpointId"
)

echo "🔄 Fetching CloudFormation output values..."
for KEY in "${!RESOURCE_IDS[@]}"; do
  RESOURCE_IDS[$KEY]=$(aws cloudformation describe-stacks --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='${RESOURCE_IDS[$KEY]}'].OutputValue" \
    --output text --region $AWS_REGION)
done

# Wait for EC2 instances to be running (both Bastion and Private EC2)
while true; do
  if [[ -z "${RESOURCE_IDS["BASTION_INSTANCE"]}" || "${RESOURCE_IDS["BASTION_INSTANCE"]}" == "None" ]]; then
    echo "❌ ERROR: Bastion EC2 Instance ID not found."
    exit 1
  fi
  if [[ -z "${RESOURCE_IDS["PRIVATE_EC2_INSTANCE"]}" || "${RESOURCE_IDS["PRIVATE_EC2_INSTANCE"]}" == "None" ]]; then
    echo "❌ ERROR: Private EC2 Instance ID not found."
    exit 1
  fi

  BASTION_STATE=$(aws ec2 describe-instances --instance-ids "${RESOURCE_IDS["BASTION_INSTANCE"]}" --query "Reservations[0].Instances[0].State.Name" --output text --region $AWS_REGION)
  PRIVATE_EC2_STATE=$(aws ec2 describe-instances --instance-ids "${RESOURCE_IDS["PRIVATE_EC2_INSTANCE"]}" --query "Reservations[0].Instances[0].State.Name" --output text --region $AWS_REGION)

  if [[ "$BASTION_STATE" == "running" && "$PRIVATE_EC2_STATE" == "running" ]]; then
    echo "✅ Both Bastion and Private EC2 instances are running."
    break
  else
    echo "⏳ Waiting for EC2 instances to be running..."
    sleep 30
  fi
done

echo "🚀 Deployment completed successfully!"
