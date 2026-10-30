terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 6.71.0" } }
}
provider "aws" { region = "us-east-1" }
variable "github_repository" {
  description = "Exact owner/repository; case sensitive OIDC subject."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Supply owner/repository."
  }
}
variable "existing_oidc_provider_arn" {
  type        = string
  default     = null
  description = "Reuse the account GitHub OIDC provider if it already exists."
}
data "aws_caller_identity" "current" {}
locals {
  account      = data.aws_caller_identity.current.account_id
  bucket       = "siwes-week13-state-${local.account}-us-east-1"
  key          = "week13/terraform.tfstate"
  provider_arn = var.existing_oidc_provider_arn == null ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn
}
resource "aws_s3_bucket" "state" {
  bucket = local.bucket
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Deny", Principal = "*", Action = "s3:*",
    Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"],
    Condition = { Bool = { "aws:SecureTransport" = "false" } }
  }] })
}
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.existing_oidc_provider_arn == null ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
resource "aws_iam_role" "ci" {
  for_each = { plan = "terraform-plan", apply = "terraform-production" }
  name     = "week13-terraform-${each.key}"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Action = "sts:AssumeRoleWithWebIdentity",
    Principal = { Federated = local.provider_arn },
    Condition = { StringEquals = {
      "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:environment:${each.value}"
    } }
  }] })
}
resource "aws_iam_role_policy" "read" {
  for_each = aws_iam_role.ci
  role     = each.value.id
  name     = "terraform-read-and-state"
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    # Describe/list operations used by provider refresh often require Resource=*.
    { Effect = "Allow", Action = ["ec2:Describe*", "elasticloadbalancing:Describe*", "ecs:Describe*", "ecs:List*", "application-autoscaling:Describe*", "rds:DescribeDBInstances", "rds:DescribeDBSubnetGroups", "rds:ListTagsForResource", "ecr:DescribeRepositories", "ecr:DescribeImages", "ecr:ListTagsForResource", "logs:DescribeLogGroups", "logs:ListTagsForResource", "logs:ListTagsLogGroup", "cloudwatch:DescribeAlarms"], Resource = "*" },
    { Effect = "Allow", Action = ["iam:GetRole", "iam:ListRolePolicies", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole"], Resource = "arn:aws:iam::${local.account}:role/week13-ecs-app-*" },
    { Effect = "Allow", Action = ["application-autoscaling:ListTagsForResource"], Resource = "arn:aws:application-autoscaling:us-east-1:${local.account}:scalable-target/*" },
    { Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.state.arn, Condition = { StringLike = { "s3:prefix" = [local.key, "${local.key}.tflock", "env:/"] } } },
    { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.state.arn}/${local.key}" },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.state.arn}/${local.key}.tflock" }
  ] })
}
resource "aws_iam_role_policy" "apply" {
  name = "week13-deploy"
  role = aws_iam_role.ci["apply"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = "s3:PutObject", Resource = "${aws_s3_bucket.state.arn}/${local.key}" },
    { Effect = "Allow", Action = ["ecs:CreateCluster", "ecs:DeleteCluster", "ecs:UpdateCluster", "ecs:UpdateClusterSettings", "ecs:CreateService", "ecs:UpdateService", "ecs:DeleteService", "ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition", "ecs:TagResource", "ecs:UntagResource"], Resource = ["arn:aws:ecs:us-east-1:${local.account}:cluster/week13-ecs-app", "arn:aws:ecs:us-east-1:${local.account}:service/week13-ecs-app/week13-ecs-app", "arn:aws:ecs:us-east-1:${local.account}:task-definition/week13-ecs-app:*"] },
    { Effect = "Allow", Action = ["elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer", "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:SetSecurityGroups", "elasticloadbalancing:SetSubnets", "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup", "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes", "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener", "elasticloadbalancing:ModifyListener", "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"], Resource = ["arn:aws:elasticloadbalancing:us-east-1:${local.account}:loadbalancer/app/week13-ecs-app/*", "arn:aws:elasticloadbalancing:us-east-1:${local.account}:targetgroup/week13-ecs-app/*", "arn:aws:elasticloadbalancing:us-east-1:${local.account}:listener/app/week13-ecs-app/*/*"] },
    { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy", "logs:TagResource", "logs:UntagResource"], Resource = ["arn:aws:logs:us-east-1:${local.account}:log-group:/ecs/week13-ecs-app", "arn:aws:logs:us-east-1:${local.account}:log-group:/ecs/week13-ecs-app:*"] },
    { Effect = "Allow", Action = ["iam:CreateRole", "iam:DeleteRole", "iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:TagRole", "iam:UntagRole"], Resource = "arn:aws:iam::${local.account}:role/week13-ecs-app-*" },
    { Effect = "Allow", Action = "iam:PassRole", Resource = ["arn:aws:iam::${local.account}:role/week13-ecs-app-task", "arn:aws:iam::${local.account}:role/week13-ecs-app-execution"], Condition = { StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" } } },
    { Effect = "Allow", Action = ["iam:CreateServiceLinkedRole"], Resource = "arn:aws:iam::${local.account}:role/aws-service-role/*", Condition = { StringEquals = { "iam:AWSServiceName" = ["ecs.amazonaws.com", "elasticloadbalancing.amazonaws.com", "ecs.application-autoscaling.amazonaws.com"] } } },
    { Effect = "Allow", Action = ["application-autoscaling:RegisterScalableTarget", "application-autoscaling:DeregisterScalableTarget", "application-autoscaling:PutScalingPolicy", "application-autoscaling:DeleteScalingPolicy"], Resource = "arn:aws:application-autoscaling:us-east-1:${local.account}:scalable-target/*", Condition = { StringEquals = { "application-autoscaling:service-namespace" = "ecs" } } },
    { Effect = "Allow", Action = ["ec2:CreateSecurityGroup", "ec2:CreateVpcEndpoint", "ec2:CreateTags"], Resource = ["arn:aws:ec2:us-east-1:${local.account}:security-group/*", "arn:aws:ec2:us-east-1:${local.account}:vpc-endpoint/*", "arn:aws:ec2:us-east-1:${local.account}:vpc/vpc-08cb55538e782f57c", "arn:aws:ec2:us-east-1:${local.account}:subnet/subnet-0982d8fffa95c1dd5", "arn:aws:ec2:us-east-1:${local.account}:subnet/subnet-0e2eaf1cd6e2a5882"] },
    { Effect = "Allow", Action = ["ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress", "ec2:DeleteSecurityGroup", "ec2:ModifyVpcEndpoint", "ec2:DeleteVpcEndpoints"], Resource = ["arn:aws:ec2:us-east-1:${local.account}:security-group/*", "arn:aws:ec2:us-east-1:${local.account}:vpc-endpoint/*"], Condition = { StringEquals = { "ec2:ResourceTag/Project" = "SIWES-Week13" } } },
    { Effect = "Allow", Action = ["application-autoscaling:TagResource", "application-autoscaling:UntagResource"], Resource = "arn:aws:application-autoscaling:us-east-1:${local.account}:scalable-target/*", Condition = { StringEquals = { "aws:ResourceTag/Project" = "SIWES-Week13" } } },
    # Explicitly prohibit alteration/deletion of the pre-existing data and registry tiers.
    { Effect = "Deny", Action = ["rds:DeleteDBInstance", "rds:ModifyDBInstance", "rds:DeleteDBSubnetGroup", "ecr:DeleteRepository", "ecr:BatchDeleteImage", "ec2:DeleteVpc", "ec2:DeleteSubnet"], Resource = "*" }
  ] })
}
output "state_bucket" { value = aws_s3_bucket.state.id }
output "plan_role_arn" { value = aws_iam_role.ci["plan"].arn }
output "apply_role_arn" { value = aws_iam_role.ci["apply"].arn }
