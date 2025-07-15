# Configure the AWS Provider
# Ensure you have your AWS credentials configured (e.g., via AWS CLI, environment variables)
provider "aws" {
  region = "us-east-1" # You can change your desired AWS region here
}

# --- S3 Bucket Resource (Optional, but good for a complete example) ---
# This creates an S3 bucket that the EC2 instance will interact with.
resource "aws_s3_bucket" "example_bucket" {
  bucket = "my-dvwa-data-bucket-unique-name-12345" # IMPORTANT: S3 bucket names must be globally unique
  acl    = "private" # Keep the bucket private, access will be granted via IAM role

  tags = {
    Name        = "DVWA Data Bucket"
    Environment = "Dev"
  }
}

# --- IAM Policy for S3 Access ---
# This policy grants permissions to list, get, and put objects in the specified S3 bucket.
# The `s3:*` action grants full access to the bucket, which aligns with "high permissions".
# For production, it's recommended to narrow down permissions (e.g., s3:GetObject, s3:PutObject).
data "aws_iam_policy_document" "s3_access_policy" {
  statement {
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.example_bucket.arn,
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject", # Add delete if needed for "high permissions"
    ]
    resources = [
      "${aws_s3_bucket.example_bucket.arn}/*", # Grant access to objects within the bucket
    ]
  }
}

# --- IAM Role for EC2 Instance ---
# This role allows EC2 instances to assume it.
resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
      },
    ],
  })

  tags = {
    Name = "EC2 S3 Access Role"
  }
}

# --- Attach S3 Access Policy to the IAM Role ---
resource "aws_iam_role_policy" "s3_policy_attachment" {
  name   = "s3-full-access-policy"
  role   = aws_iam_role.ec2_s3_role.id
  policy = data.aws_iam_policy_document.s3_access_policy.json
}

# --- IAM Instance Profile ---
# An instance profile is a container for an IAM role that you can use to pass role information to an EC2 instance.
resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "ec2-s3-instance-profile"
  role = aws_iam_role.ec2_s3_role.name
}

# --- Security Group for EC2 Instance ---
# This security group allows SSH (port 22) and HTTP (port 80) access from anywhere.
# For production, restrict source IPs to known ranges.
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2-public-access-sg"
  description = "Allow SSH and HTTP access to EC2 instance"
  vpc_id      = data.aws_vpc.default.id # Assumes a default VPC exists

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Allows SSH from anywhere. Restrict in production.
    description = "Allow SSH from anywhere"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Allows HTTP from anywhere. Restrict in production.
    description = "Allow HTTP from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EC2 Public Access SG"
  }
}

# --- Data Source for Default VPC ---
# This helps find your default VPC to attach the security group.
data "aws_vpc" "default" {
  default = true
}

# --- EC2 Instance ---
resource "aws_instance" "dvwa_instance" {
  ami           = "ami-053b0d53c279acc90" # Amazon Linux 2 AMI (us-east-1). Choose an AMI appropriate for your region.
  instance_type = "t2.micro" # Free tier eligible instance type
  key_name      = "my-ssh-key" # IMPORTANT: Replace with your actual SSH key pair name
  associate_public_ip_address = true # Assign a public IP for internet access
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_s3_profile.name

  tags = {
    Name = "DVWA-EC2-Instance"
  }
}

# --- Output the Public IP of the EC2 Instance ---
output "ec2_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.dvwa_instance.public_ip
}

# --- Output the S3 Bucket Name ---
output "s3_bucket_name" {
  description = "The name of the S3 bucket created"
  value       = aws_s3_bucket.example_bucket.id
}
