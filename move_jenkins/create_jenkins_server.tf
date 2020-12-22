terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

provider "aws" {
  # access_key = "***FM7R"
  # secret_key = "*******"
  profile    = "default"
  region     = "us-east-1"
}

variable "instance-type" {
  type    = string
  default = "t2.medium"
}

resource "aws_key_pair" "jenkins_keypair" {
  key_name   = "jenkins-petclinic"
  public_key = file("~/.ssh/the-one-key.pub")
}

data "aws_ssm_parameter" "linuxAmi" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

resource "aws_security_group" "jenkins-sg" {
  name        = "petclinic-jenkins-master-sg"
  description = "petclinic-jenkins-master-sg-22-80-8080"
  ingress {
    description = "allow ssh from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "open port 80 to anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "open jenkins port to anywhere"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_instance_profile" "jenkins_petclinic_profile" {
  name = "jenkins_petclinic_profile"
  role = aws_iam_role.jenkins-role.name
}

resource "aws_iam_role" "jenkins-role" {
  name               = "jenkins-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags = {
    Name = "jenkins-role"
  }
}

resource "aws_iam_role_policy" "jenkins-policy" {
  name   = "jenkins-policy"
  role   = aws_iam_role.jenkins-role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:CreateInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:GetRole",
                "iam:GetInstanceProfile",
                "iam:GetPolicy",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:DeletePolicy",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:AttachRolePolicy",
                "iam:AddRoleToInstanceProfile",
                "iam:CreatePolicy",
                "iam:PassRole",
                "iam:DetachRolePolicy",
                "iam:ListPolicyVersions"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:*",
                "cloudtrail:LookupEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_instance" "jenkins-server" {
  ami                    = data.aws_ssm_parameter.linuxAmi.value
  instance_type          = var.instance-type
  key_name               = aws_key_pair.jenkins_keypair.key_name
  vpc_security_group_ids = [aws_security_group.jenkins-sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_petclinic_profile.name
  tags = {
    Name = "jenkins_server"
  }
  provisioner "local-exec" {
    command = <<EOF
aws ec2 wait instance-status-ok --instance-ids ${self.id}
ansible-playbook -i dynamic_inventory_aws_ec2.yaml --private-key ~/.ssh/the-one-key --extra-vars 'new_jenkins_server=tag_Name_${self.tags.Name}' move_jenkins_server.yaml
EOF
  }
}