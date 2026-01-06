# AWS MLOps Project – Banking Classification Model Deployment

This project shows how to deploy a Flask-based ML classification model on **Amazon EKS** using a fully automated **AWS MLOps pipeline**.  
The setup includes Docker containerization, CI/CD with AWS CodePipeline, and Infrastructure as Code using Terraform.


---

## Key Components
- **Model App:** Flask-based ML model for classification  
- **Containerization:** Docker  
- **Deployment:** Amazon EKS (Kubernetes)  
- **CI/CD:** CodeBuild + CodePipeline  
- **Storage:** Amazon S3 + ECR  
- **IaC:** Terraform  

---

## Repositories
There are two GitHub repositories in this project:
1. **banking** → Contains Flask ML code and Dockerfile  
2. **banking_eks** → Contains Kubernetes YAMLs (Deployment, Service, Ingress)

Each repo has its own workflow and CodePipeline setup.

---

## Workflow Overview


1. **Deploy on EKS**
   - New Docker images trigger the deployment pipeline.
   - Updated images are deployed on the **Amazon EKS cluster**.

3. **Load Balancing & Monitoring**
   - **AWS Load Balancer Controller** manages incoming requests.
   - **Kubernetes Dashboard** used for real-time monitoring.

4. **Infrastructure as Code**
   - All AWS resources (ECR, EKS, CodeBuild, CodePipeline) can also be provisioned using **Terraform** alongside AWS UI.

-


## Quick Setup Guide

1. Create two GitHub Repositories

2. You can create the Services using UI

2. You can also Terraform to provision AWS Resources (Take the terraform code from Code/Terraform)

cd terraform/
terraform init
terraform plan -var-file="secret.tfvars
terraform apply -var-file="secret.tfvars

This will create the required AWS resources (ECR, EKS, CodeBuild, CodePipeline).

3. Push Code to GitHub
Each commit triggers:

Pipeline 1: Build & push Docker image to AWS ECR

Pipeline 2: Deploy latest docker image on AWS EKS

4. Test the Deployed App
Once deployed, get your ALB DNS name from AWS Console. Check the health status of the application

curl http://<load-balancer-dns>/healthstatus


### For prediction, make POST Request on AWS EKS where application is deployed

curl -X POST http://<load-balancer-dns>/bank-classification
