# AWS MLOps Project – Banking Classification Model Deployment Part 2

This project shows how to deploy a Flask-based ML classification model on **Amazon EKS** using a fully automated **AWS MLOps pipeline**.  
The setup includes Docker containerization, CI/CD with AWS CodePipeline, and Infrastructure as Code using Terraform.

## Aim
Build and deploy a machine learning model to perform focused digital marketing by predicting the potential customers who will convert from liability customers to asset customers.

---
## Tree Structure
```
C:.
│   GitHub Commands.txt
│   Kubernetes_commands.txt
│   Readme.md
│
├───banking-classification
│   │   .dockerignore
│   │   .gitignore
│   │   buildspec.yaml
│   │   Dockerfile
│   │
│   └───FlaskApplication
│       │   requirements.txt
│       │
│       ├───input
│       │       Data1.csv
│       │       Data2.csv
│       │
│       ├───lib
│       │       Digital_transformation_in_Banking_sector.ipynb
│       │
│       ├───output
│       │       finalized_model.sav
│       │
│       └───src
│           │   .env
│           │   .env.dev
│           │   .env.prod
│           │   .flaskenv
│           │   app.py
│           │   Engine.py
│           │   gunicorn.sh
│           │   logging_module.py
│           │   predictor.py
│           │   requirements.txt
│           │
│           ├───logs
│           │       debug.log
│           │       error.log
│           │
│           ├───ML_Pipeline
│           │   │   grid_model.py
│           │   │   model_evaluation.py
│           │   │   train_model.py
│           │   │   utils.py
│           │   │
│           │   └───__pycache__
│           │           utils.cpython-38.pyc
│           │
│           └───__pycache__
│                   logging_module.cpython-38.pyc
│                   predictor.cpython-38.pyc
│
├───banking-classification-eks
│       alb-svc.yaml
│       aws-auth.yaml
│       buildspec.yaml
│       deployment.yaml
│       env
│       iam_policy.json
│       ingress.yaml
│       kubectl
│       kubernetes-dashboard-admin.yaml
│       namespace.yaml
│       service.yaml
│
├───results
└───Terraform
    │   Data1.csv
    │   Data2.csv
    │   Instructions.md
    │   main.tf
    │   providers.tf
    │   secrets.tfvars
    │   Terraform_Commands.txt
    │
    └───.aws
        └───creds
                creds
```
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
* banking** → Contains Flask ML code and Dockerfile  
* banking_eks** → Contains Kubernetes YAMLs (Deployment, Service, Ingress)

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
