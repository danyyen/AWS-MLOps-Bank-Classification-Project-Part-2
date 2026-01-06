### Prerequisites:

Install AWS CLI and configure your credentials using aws configure. Install Terraform on your system.


### Using a variable file (secret.tfvars) allows you to securely pass sensitive credentials and configuration values.

# AWS account details
account_id          = ""         # Replace with your AWS account ID
aws_access_key_id   = ""  # Replace with your AWS access key
aws_secret_access_key = "" # Replace with your AWS secret key

# GitHub repository details
github_owner        = ""       # GitHub username or org
github_repo_a        = "banking"       # GitHub repository name
github_repo_b        = "banking_eks"       # GitHub repository name
github_token        = ""       # Personal access token with repo access


### AWS CLI Installation Link

https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html


### Configure AWS CLI on Your System

## Execute this command on Terminal to setup AWS CLI on the local system
```aws configure```


1. Enter your AWS Access Key ID and Secret Access Key.
2. Specify the region where your IAM user has access.


This sets up local system to interact with AWS services using the CLI and necessary for the execution using terraform.


### Terraform Installation Link

https://developer.hashicorp.com/terraform/downloads

###### Install Terraform on Windows 

1. https://releases.hashicorp.com/terraform/1.13.4/terraform_1.13.4_windows_amd64.zip
2. Download the ZIP file and extract it.
3. Copy the extracted terraform.exe file.
4. Open File Explorer → navigate to C:\Program Files.
5. Create a new folder named Terraform and paste the terraform.exe file inside it.
6. Add Terraform to your system PATH:
7. Click Environment Variables → under System variables, select Path → click Edit.
8. Click New, then paste the Terraform folder path (e.g., C:\Program Files\Terraform) and Click OK to save changes.

Open Command Prompt and verify installation:

```terraform -version```


###### Install Terraform on macOS

If you don’t have Homebrew installed, first install it by executing this command on the terminal:

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"


## Run this commmand to install terraform on macOS
1. brew tap hashicorp/tap
2. brew install hashicorp/tap/terraform


##### Terraform Commands
Step 1: Initialize Terraform
```terraform init```


This command sets up your working directory for Terraform. It downloads the required providers and prepares the environment for deployment.


Step 2: Preview Terraform Plan with passing secret variables from secrets.tfvars
```terraform plan -var-file="secret.tfvars```


This command shows all the changes Terraform will make to infrastructure. You can review the changes safely before actually applying them.

Step 3: Validate Terraform Configuration with passing secret variables from secrets.tfvars
```terraform validate -var-file="secret.tfvars```


This command checks all Terraform files for syntax errors. It ensures that configuration is correct before applying it.

Step 4: Apply Terraform Changes (Interactive) with passing secret variables from secrets.tfvars
```terraform apply -var-file="secret.tfvars```


This command applies your Terraform configuration to create or update resources in AWS. You will be prompted to confirm before Terraform makes any changes.


Step 5: Apply Terraform Changes Automatically
```terraform apply -var-file="secret.tfvars --auto-approve```


This command applies all Terraform changes without asking for confirmation. It is useful for automated deployments or pipelines.


Step 6: Destroy Terraform Resources
```terraform destroy -var-file="secret.tfvars```

This command removes all resources that were created and managed by Terraform. Use this command carefully to avoid accidentally deleting important resources.