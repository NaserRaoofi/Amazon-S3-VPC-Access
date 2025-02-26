# Managing-Access-to-Amazon-S3-Resources-with-Amazon-VPC-Endpoints
Managing Access to Amazon S3 Resources with Amazon VPC Endpoints
![architecture-diagram 1](https://github.com/user-attachments/assets/c6b587cf-b954-45ee-86ef-a51400669936)

## 📌 Overview
This project automates the deployment of a secure **AWS infrastructure** that enables **private EC2 instances** to communicate with **Amazon S3** via an **S3 Gateway Endpoint**. The entire infrastructure is deployed using **AWS CloudFormation** and managed with a **Bash script**.

## 🎯 Key Features
- **VPC & Networking**
  - Custom **VPC** with private and public subnets
  - **Internet Gateway (IGW)** for external access
  - **Route Tables** for public/private traffic control
- **Security & Access Management**
  - **Security Groups (SGs)** with defined inbound/outbound rules
  - **Network ACLs (NACLs)** for extra traffic security
  - **IAM Role & Policies** for EC2 to access S3 securely
- **Compute & Storage**
  - **Bastion Host** for SSH access to private EC2
  - **Private EC2 Instance** communicating with S3
  - **S3 Gateway Endpoint** for internal S3 access
- **Automation & Deployment**
  - **CloudFormation Templates** for infrastructure as code (IaC)
  - **Bash Script** for automatic stack deployment
  - **Key Pair Management** for secure SSH access

## 📜 Architecture Diagram
```
   Internet Gateway
        │
   ┌────┴────┐
   │  VPC   │
   └────────┘
       │
 ┌────┴────┐
 │ Public  │─────────── Bastion Host (SSH)
 └─────────┘
       │
 ┌────┴────┐
 │ Private │───(Private EC2)─── S3 Gateway Endpoint ─── S3 Bucket
 └─────────┘
```

## 🚀 Deployment Steps
### 1️⃣ Prerequisites
Ensure you have:
- **AWS CLI** installed and configured
- **CloudFormation Templates** uploaded to an S3 bucket
- **Key Pair** generated and moved to the Bastion host

### 2️⃣ Deploying the Stack
Run the **Bash script** to create and manage CloudFormation stacks:
```bash
./deploy.sh
```
This script:
- Uploads templates to S3
- Checks for existing stacks
- Creates/updates the stack automatically

### 3️⃣ SSH Access to Private EC2
- Connect to the Bastion host:
```bash
ssh -i ec2-key-pair.pem ec2-user@<Bastion-Public-IP>
```
- Move the private key to Bastion:
```bash
scp -i ec2-key-pair.pem bastion-key-pair.pem ec2-user@<Bastion-Public-IP>:~
```
- SSH into the private instance:
```bash
ssh -i bastion-key-pair.pem ec2-user@<Private-EC2-Private-IP>
```

### 4️⃣ Test S3 Access from Private EC2
Once inside the **private EC2 instance**, verify access to S3:
```bash
aws s3 ls --region eu-west-2
```
If you see the S3 bucket list, the setup is successful!

## 📂 CloudFormation Stack Details
| Stack Name          | Description |
|---------------------|-------------|
| **VPCStack**       | Creates the VPC & subnets |
| **IGWStack**       | Deploys Internet Gateway |
| **SecurityGroupStack** | Defines security groups |
| **SubnetStack**    | Configures public/private subnets |
| **RouteTableStack** | Adds routing tables & routes |
| **S3EndpointStack** | Creates S3 Gateway Endpoint |
| **EC2Stack**       | Launches Bastion & Private EC2 |

## 🏆 Benefits
✅ Secure **private communication** with S3 (no internet required)  
✅ Fully **automated** deployment with **Infrastructure as Code (IaC)**  
✅ **Scalable & modular** CloudFormation templates  
✅ Follows AWS **best practices** for networking & security  

## 📌 Next Steps
- Implement **CloudWatch** logging for monitoring
- Add **IAM restrictions** for fine-grained permissions
- Configure **AWS Systems Manager (SSM)** for bastion-less access

📂 GitHub Repository

Check out the full code here:
[Amazon-S3-VPC-Access](https://github.com/NaserRaoofi/Amazon-S3-VPC-Access)

📢 LinkedIn Profile

Let's connect on LinkedIn:
www.linkedin.com/in/naser-raoofi

## 📢 Let's Connect
Share your thoughts or feedback! 🚀  
#AWS #CloudFormation #Networking #S3Gateway #BastionHost #InfrastructureAsCode #DevOps #AWSVPC #Security #AWSAutomation


