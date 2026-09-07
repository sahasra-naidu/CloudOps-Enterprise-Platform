terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

# -------------------------
# VPC
# -------------------------

resource "aws_vpc" "cloudops_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "cloudops-vpc"
    Project = "CloudOps Enterprise Platform"
  }
}

# -------------------------
# Internet Gateway
# -------------------------

resource "aws_internet_gateway" "cloudops_igw" {
  vpc_id = aws_vpc.cloudops_vpc.id

  tags = {
    Name = "cloudops-internet-gateway"
  }
}

# -------------------------
# Public Subnet
# -------------------------

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.cloudops_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "cloudops-public-subnet"
  }
}

# -------------------------
# Private Subnet
# -------------------------

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.cloudops_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "cloudops-private-subnet"
  }
}

# -------------------------
# Public Route Table
# -------------------------

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.cloudops_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloudops_igw.id
  }

  tags = {
    Name = "cloudops-public-route-table"
  }
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# -------------------------
# Security Group
# -------------------------

resource "aws_security_group" "cloudops_sg" {
  name        = "cloudops-security-group"
  description = "Security group for CloudOps application"
  vpc_id      = aws_vpc.cloudops_vpc.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Application port
  ingress {
    description = "Application"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloudops-security-group"
  }
}

# -------------------------
# EC2 Instance
# -------------------------

resource "aws_instance" "cloudops_server" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.cloudops_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash

              apt-get update -y
              apt-get install -y docker.io

              systemctl enable docker
              systemctl start docker

              usermod -aG docker ubuntu

              echo "CloudOps Enterprise Platform Server" > /var/www.html
              EOF

  tags = {
    Name    = "cloudops-server"
    Project = "CloudOps Enterprise Platform"
  }
}
# ---------------------------------------------------------
# S3 BUCKET
# ---------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "cloudops_data" {
  bucket = "cloudops-enterprise-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "CloudOps Enterprise Data"
    Environment = "production"
  }
}

resource "aws_s3_bucket_versioning" "cloudops_data" {
  bucket = aws_s3_bucket.cloudops_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudops_data" {
  bucket = aws_s3_bucket.cloudops_data.id

  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

# ---------------------------------------------------------
# LAMBDA IAM ROLE
# ---------------------------------------------------------

resource "aws_iam_role" "lambda_s3_role" {
  name = "cloudops-lambda-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ---------------------------------------------------------
# LAMBDA FUNCTION
# ---------------------------------------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/index.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "s3_processor" {
  function_name = "cloudops-s3-processor"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role    = aws_iam_role.lambda_s3_role.arn
  handler = "index.lambda_handler"
  runtime = "python3.12"

  timeout = 30

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]
}

# ---------------------------------------------------------
# S3 → LAMBDA EVENT TRIGGER
# ---------------------------------------------------------

resource "aws_lambda_permission" "allow_s3" {
  statement_id = "AllowS3Invoke"

  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.s3_processor.function_name

  principal = "s3.amazonaws.com"

  source_arn = aws_s3_bucket.cloudops_data.arn
}

resource "aws_s3_bucket_notification" "cloudops_data" {
  bucket = aws_s3_bucket.cloudops_data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_processor.arn

    events = [
      "s3:ObjectCreated:*"
    ]
  }

  depends_on = [
    aws_lambda_permission.allow_s3
  ]
}
# ---------------------------------------------------------
# SECOND PRIVATE SUBNET FOR RDS
# ---------------------------------------------------------

resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.cloudops_vpc.id
  cidr_block              = var.private_subnet_2_cidr
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = false

  tags = {
    Name = "cloudops-private-subnet-2"
  }
}
# ---------------------------------------------------------
# RDS SECURITY GROUP
# ---------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "cloudops-rds-sg"
  description = "Allow PostgreSQL access only from the CloudOps EC2 security group"
  vpc_id      = aws_vpc.cloudops_vpc.id

  ingress {
    description     = "PostgreSQL from CloudOps EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.cloudops_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloudops-rds-sg"
  }
}
# ---------------------------------------------------------
# RDS SUBNET GROUP
# ---------------------------------------------------------

resource "aws_db_subnet_group" "cloudops_db" {
  name = "cloudops-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_subnet.id,
    aws_subnet.private_2.id
  ]

  tags = {
    Name = "CloudOps RDS Subnet Group"
  }
}
# ---------------------------------------------------------
# RDS POSTGRESQL DATABASE
# ---------------------------------------------------------

resource "aws_db_instance" "cloudops_db" {
  identifier = "cloudops-enterprise-db"

  engine         = "postgres"
  engine_version = "16"

  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  max_allocated_storage = 20
  storage_type          = "gp3"

  db_name  = "cloudops"
  username = "cloudopsadmin"
  password = "CloudOpsDB2026Secure!"

  db_subnet_group_name   = aws_db_subnet_group.cloudops_db.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

  backup_retention_period = 1

  tags = {
    Name        = "CloudOps PostgreSQL"
    Environment = "production"
  }
}