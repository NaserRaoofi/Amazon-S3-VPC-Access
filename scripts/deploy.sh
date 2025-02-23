#!/bin/bash

# Variables
STACK_NAME="MainStack"
S3_BUCKET="developer-bucket-v1"
VPC_TEMPLATE="code/vpc.yaml"
IGW_TEMPLATE="code/igw.yaml"

# Convert Unix path to Windows path (for AWS CLI compatibility in Git Bash)
PARENT_TEMPLATE="$(cygpath -w '/e/aws Lab projects/Amazon-S3-VPC-Access/templates/main.yaml')"
CHILD_TEMPLATE_VPC="$(cygpath -w '/e/aws Lab projects/Amazon-S3-VPC-Access/templates/vpc.yaml')"
CHILD_TEMPLATE_IGW="$(cygpath -w '/e/aws Lab projects/Amazon-S3-VPC-Access/templates/igw.yaml')"

# Ensure AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it and configure your credentials."
    exit 1
fi

# Ensure template files exist
if [[ ! -f "$CHILD_TEMPLATE_VPC" ]]; then
    echo "❌ ERROR: vpc.yaml not found at $CHILD_TEMPLATE_VPC"
    exit 1
fi

if [[ ! -f "$CHILD_TEMPLATE_IGW" ]]; then
    echo "❌ ERROR: igw.yaml not found at $CHILD_TEMPLATE_IGW"
    exit 1
fi

# Upload VPC and IGW templates to S3
echo "📤 Uploading vpc.yaml to S3..."
aws s3 cp "$CHILD_TEMPLATE_VPC" s3://$S3_BUCKET/$VPC_TEMPLATE --acl private

echo "📤 Uploading igw.yaml to S3..."
aws s3 cp "$CHILD_TEMPLATE_IGW" s3://$S3_BUCKET/$IGW_TEMPLATE --acl private

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

# Retrieve VPC and IGW IDs
VPC_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='VPCId'].OutputValue" --output text)

IGW_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='InternetGatewayId'].OutputValue" --output text)

if [[ -z "$VPC_ID" ]]; then
    echo "❌ ERROR: Failed to retrieve VPC ID."
    exit 1
else
    echo "✅ VPC Created Successfully! VPC ID: $VPC_ID"
fi

if [[ -z "$IGW_ID" ]]; then
    echo "❌ ERROR: Failed to retrieve Internet Gateway ID."
    exit 1
else
    echo "✅ Internet Gateway Created Successfully! IGW ID: $IGW_ID"
fi
