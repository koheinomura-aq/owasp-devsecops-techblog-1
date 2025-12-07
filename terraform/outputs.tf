########################################
# VPC / サブネット情報の出力
########################################

# 構築したVPCのID
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.devsecops.id
}

# 各プライベートサブネットのID一覧
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

# SSM Session Managerで接続する踏み台EC2のインスタンスID
output "bastion_instance_id" {
  description = "Instance ID of the Bastion host for SSM connection"
  value       = aws_instance.bastion.id
}

# 内部ALBのDNS名（ポートフォワード時に利用）
output "alb_dns_name" {
  description = "Internal ALB DNS Name (for SSM Port Forwarding)"
  value       = aws_lb.internal.dns_name
}

# 各種Interface型VPCエンドポイントの DNS 名一覧
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
# GitHub Actions用CI/CDパラメータ出力
########################################

# GitHub Actionsから参照するECRリポジトリURL
output "ecr_repository_url" {
  description = "ECR repository URL for GitHub Actions"
  value       = aws_ecr_repository.juiceshop.repository_url
}

# GitHub Actionsから参照するECSクラスタ名
output "ecs_cluster_name" {
  description = "ECS cluster name for GitHub Actions"
  value       = aws_ecs_cluster.devsecops.name
}

# Staging環境のECSサービス名
output "stg_service_name" {
  description = "Staging ECS service name"
  value       = aws_ecs_service.stg.name
}

# Production環境のECSサービス名
output "prd_service_name" {
  description = "Production ECS service name"
  value       = aws_ecs_service.prd.name
}

# GitHub ActionsからAssumeさせるIAMロールのARN
# → terraform output github_actions_role_arnで取得し、GitHub Secretsに設定する
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions (OIDC)"
  value       = aws_iam_role.github_actions.arn
}
