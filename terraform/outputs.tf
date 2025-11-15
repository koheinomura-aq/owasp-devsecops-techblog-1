########################################
# VPC / サブネット情報の出力
########################################

# 構築した VPC の ID
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.devsecops_vpc.id
}

# 各プライベートサブネットの ID 一覧
output "subnets" {
  description = "Private subnets for all resources"
  value = {
    private_a = aws_subnet.private_a.id
    private_c = aws_subnet.private_c.id
  }
}

########################################
# 接続・アクセスに関する情報の出力
########################################

# SSM Session Manager で接続する踏み台 EC2 のインスタンス ID
output "bastion_instance_id" {
  description = "Instance ID of the Bastion host for SSM connection"
  value       = aws_instance.bastion.id
}

# 内部 ALB の DNS 名（ポートフォワード時に利用）
output "alb_dns_name" {
  description = "Internal ALB DNS Name (for SSM Port Forwarding)"
  value       = aws_lb.internal_alb.dns_name
}

# 各種 Interface 型 VPC エンドポイントの DNS 名一覧
output "vpc_endpoints_dns" {
  description = "DNS entries for Interface VPC Endpoints"
  value = {
    ssm         = aws_vpc_endpoint.ssm.dns_entry[0].dns_name
    ec2messages = aws_vpc_endpoint.ec2messages.dns_entry[0].dns_name
    ssmmessages = aws_vpc_endpoint.ssmmessages.dns_entry[0].dns_name
    ecr_api     = aws_vpc_endpoint.ecr_api.dns_entry[0].dns_name
    ecr_dkr     = aws_vpc_endpoint.ecr_dkr.dns_entry[0].dns_name
    logs        = aws_vpc_endpoint.logs.dns_entry[0].dns_name
  }
}

########################################
# GitHub Actions 用 CI/CD パラメータ出力
########################################

# GitHub Actions から参照する ECR リポジトリ URL
output "ecr_repository_url" {
  description = "ECR repository URL for GitHub Actions"
  value       = aws_ecr_repository.juiceshop_repo.repository_url
}

# GitHub Actions から参照する ECS クラスタ名
output "ecs_cluster_name" {
  description = "ECS cluster name for GitHub Actions"
  value       = aws_ecs_cluster.devsecops_cluster.name
}

# Staging 環境の ECS サービス名
output "stg_service_name" {
  description = "Staging ECS service name"
  value       = aws_ecs_service.stg_service.name
}

# Production 環境の ECS サービス名
output "prd_service_name" {
  description = "Production ECS service name"
  value       = aws_ecs_service.prd_service.name
}

# GitHub Actions から Assume させる IAM ロールの ARN
# → `terraform output github_actions_role_arn` で取得し、GitHub Secrets に設定する
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions (OIDC)"
  value       = aws_iam_role.github_actions.arn
}
