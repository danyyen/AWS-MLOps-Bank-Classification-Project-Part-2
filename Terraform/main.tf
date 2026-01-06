######################################
# VARIABLES
######################################
variable "account_id" {}
variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
variable "github_owner" {}
variable "github_repo_a" {}
variable "github_repo_b" {}
variable "github_token" {}


######################################
# GET EXISTING VPC AND PUBLIC SUBNETS
######################################
# Fetch default VPC (or you can filter by tag/name)
data "aws_vpc" "selected" {
  default = true
}

data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b"]  # pick 2 valid AZs only
  }
}

######################################
# S3 BUCKET + UPLOAD FILE
######################################
resource "aws_s3_bucket" "banking_bucket" {
  bucket = "banking-bucket-new-026"
  force_destroy = true
}

resource "aws_s3_bucket_object" "upload_data_file_1" {
  bucket = aws_s3_bucket.banking_bucket.id
  key    = "Data1.csv"
  source = "${path.module}/Data1.csv"
  acl    = "private"
}

resource "aws_s3_bucket_object" "upload_data_file_2" {
  bucket = aws_s3_bucket.banking_bucket.id
  key    = "Data2.csv"
  source = "${path.module}/Data2.csv"
  acl    = "private"
}


######################################
# ECR REPOSITORY
######################################
resource "aws_ecr_repository" "banking_repo" {
  name                 = "new-banking-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}


######################################
# IAM ROLE FOR EKS CLUSTER
######################################
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_attach" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_policy" "eks_custom_policy" {
  name   = "eks-custom-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VisualEditor0"
        Effect = "Allow"
        Action = "s3:*"
        Resource = "*"
      },
      {
        Sid    = "AllowLambdaTagging"
        Effect = "Allow"
        Action = "lambda:TagResource"
        Resource = "*"
      },
      {
        Sid    = "AllowCodeStarConnections"
        Effect = "Allow"
        Action = [
          "codestar-connections:PassConnection",
          "codestar-connections:GetConnection",
          "codestar-connections:CreateConnection",
          "codestar-connections:DeleteConnection",
          "codestar-connections:UpdateConnection"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_custom_attach" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = aws_iam_policy.eks_custom_policy.arn
}


######################################
# SECURITY GROUP FOR EKS
######################################
resource "aws_security_group" "eks_sg" {
  name        = "eks-demo-sg"
  description = "Security group for EKS demo cluster"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


######################################
# EKS CLUSTER
######################################
resource "aws_eks_cluster" "banking_eks_cluster" {
  name     = "banking-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.33"

  vpc_config {
    subnet_ids             = data.aws_subnets.public_subnets.ids
    endpoint_public_access = true
    endpoint_private_access = false
    security_group_ids     = [aws_security_group.eks_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_attach,
    aws_iam_role_policy_attachment.eks_custom_attach
  ]
}


######################################
# Key pair
######################################

# Generate SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Register key in AWS
resource "aws_key_pair" "keypair" {
  key_name   = "terraform-eks-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Save private key locally
resource "local_file" "private_key_pem" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/terraform-eks-key.pem"
  file_permission = "0600"
}


######################################
# IAM ROLE FOR NODE GROUP
######################################
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_attach" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])
  role       = aws_iam_role.eks_node_role.name
  policy_arn = each.value
}

######################################
# EKS NODE GROUP
######################################
resource "aws_eks_node_group" "banking_node_group" {
  cluster_name    = aws_eks_cluster.banking_eks_cluster.name
  node_group_name = "banking-eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = data.aws_subnets.public_subnets.ids

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 3
  }

  instance_types = ["t3.medium"]
  disk_size      = 20
  ami_type       = "AL2023_x86_64_STANDARD"

  remote_access {
    ec2_ssh_key               = aws_key_pair.keypair.key_name
    source_security_group_ids = [aws_security_group.eks_sg.id]
  }

  force_update_version = true
  tags = { Name = "banking-node-group" }

}

######################################
# IAM ROLES — First CODEBUILD
######################################
resource "aws_iam_role" "first_codebuild_role" {
  name = "first-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "first_codebuild_policy" {
  name = "codebuild-policy"
  role = aws_iam_role.first_codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["s3:*", "ecr:*"], Resource = "*" },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutTestCases",
          "codebuild:BatchPutCodeCoverages"
        ],
        Resource = "*"
      }
    ]
  })
}

######################################
# First CODEBUILD PROJECT
######################################
resource "aws_codebuild_project" "image_build" {
  name         = "image-build"
  service_role = aws_iam_role.first_codebuild_role.arn

  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "us-east-1"
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.account_id
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.banking_repo.name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yaml"
  }
}

######################################
# IAM ROLES — Second CODEBUILD
######################################
resource "aws_iam_role" "second_codebuild_role" {
  name = "second-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Inline policy for S3, ECR, CodeBuild logs, reports
resource "aws_iam_role_policy" "second_codebuild_policy" {
  name = "second-codebuild-policy"
  role = aws_iam_role.second_codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["s3:*", "ecr:*"], Resource = "*" },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutTestCases",
          "codebuild:BatchPutCodeCoverages"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach AWS Managed EKS policies
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.second_codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  role       = aws_iam_role.second_codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.second_codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Inline policy: EKS actions
resource "aws_iam_role_policy" "second_codebuild_eks_inline" {
  name = "second-codebuild-eks-inline"
  role = aws_iam_role.second_codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup"
        ],
        Resource = "*"
      }
    ]
  })
}

# Inline policy: STS GetCallerIdentity
resource "aws_iam_role_policy" "second_codebuild_sts_inline" {
  name = "second-codebuild-sts-inline"
  role = aws_iam_role.second_codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:GetCallerIdentity",
        Resource = "*"
      }
    ]
  })
}

######################################
# Second CODEBUILD PROJECT 
######################################
resource "aws_codebuild_project" "deploy_eks" {
  name         = "deploy-build"
  service_role = aws_iam_role.second_codebuild_role.arn

  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "us-east-1"
    }

    environment_variable {
      name  = "AWS_CLUSTER_NAME"
      value = aws_eks_cluster.banking_eks_cluster.name
    }

    environment_variable {
      name  = "AWS_ACCESS_KEY_ID"
      value = var.aws_access_key_id
    }

    environment_variable {
      name  = "AWS_SECRET_ACCESS_KEY"
      value = var.aws_secret_access_key
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yaml" # Repo B buildspec will come from GitHub source stage in pipeline
  }
}


######################################
# IAM ROLE — CODEPIPELINE
######################################
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [ {
      Effect = "Allow",
      Principal = { Service = "codepipeline.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_policy1" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_iam_role_policy_attachment" "codepipeline_policy2" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Inline policy with CodeConnections + S3 + CodeBuild
resource "aws_iam_role_policy" "codepipeline_inline_policy" {
  name = "codepipeline-inline-policy"
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        Resource = [aws_s3_bucket.banking_bucket.arn, 
        "${aws_s3_bucket.banking_bucket.arn}/*"]
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "codeconnections:UseConnection",
          "codestar-connections:UseConnection"
        ],
        Resource = "*"
      }
    ]
  })
}


##############################################
# CODEPIPELINE 1 (Build & Push to ECR)
##############################################
resource "aws_codepipeline" "pipeline_build" {
  name     = "app-build-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.banking_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]
      

      configuration = {
        Owner      = var.github_owner
        Repo       = var.github_repo_a
        Branch     = "master"
        OAuthToken = var.github_token
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.image_build.name
      }
    }
  }
}

##############################################
# CODEPIPELINE 2 (Deploy to EKS)
##############################################
resource "aws_codepipeline" "pipeline_deploy" {
  name     = "eks-deploy-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.banking_bucket.bucket
    type     = "S3"
  }

  # Stage 1: Single Source stage with ECR + GitHub
  stage {
    name = "Source"

    # Action 1: ECR trigger
    action {
      name             = "ECR_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = ["ecr_output"]

      configuration = {
        RepositoryName = aws_ecr_repository.banking_repo.name
        ImageTag       = "latest"
      }
    }

    # Action 2: GitHub source
    action {
      name             = "GitHub_RepoB"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["github_output"]

      configuration = {
        Owner      = var.github_owner
        Repo       = var.github_repo_b
        Branch     = "master"
        OAuthToken = var.github_token
      }
    }
  }

  # Stage 2: Deploy via CodeBuild
  stage {
    name = "Deploy"
    action {
      name             = "Deploy_to_EKS"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["github_output"]
      configuration = {
        ProjectName = aws_codebuild_project.deploy_eks.name
      }
    }
  }
}
