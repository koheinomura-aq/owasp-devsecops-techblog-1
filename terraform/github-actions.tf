########################################
# GitHub Actions 用 IAM 設定
########################################

# ============================================================
# 【パターン①】このAWSアカウントにGitHub OIDC Providerが
# まだ存在しない場合に使う（初回セットアップ用）
# ============================================================
#
#resource "aws_iam_openid_connect_provider" "github" {
#   url = "https://token.actions.githubusercontent.com"

#   client_id_list = [
#     "sts.amazonaws.com"
#   ]

#   thumbprint_list = [
#     # GitHub OIDC の既知フィンガープリント
#     "9e99a48a9960b14926bb7f3b02e22da0ecd4e50f"
#   ]
# }

# ============================================
# 【パターン②】既にGitHub OIDC Providerが
# 他のTerraform / 手作業で作成済みの場合に使う
# ============================================
# → 既存のOIDC Providerをdataで参照するだけ
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

########################################
# GitHub Actionsから引き受けさせるIAMロール
########################################
resource "aws_iam_role" "github_actions" {
  name = "devsecops-github-actions-role"

  # GitHub ActionsのOIDCトークンを使って
  # sts:AssumeRoleWithWebIdentityできるようにするための信頼ポリシー
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          #Federated = aws_iam_openid_connect_provider.github.arn
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # sub: このリポジトリからのワークフローだけを許可
            # 例: repo:オーナー名/リポジトリ名:*
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo_owner}/${var.github_repo_name}:*"
          }
        }
      }
    ]
  })
}

########################################
# GitHub Actionsに付与する権限
# （ECRへのpush + ECSのデプロイ更新）
########################################
resource "aws_iam_role_policy" "github_actions" {
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECRログイン&イメージの push / pull
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      # ECSサービスの更新（force-new-deployment など）
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTasks",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      }
    ]
  })
}
