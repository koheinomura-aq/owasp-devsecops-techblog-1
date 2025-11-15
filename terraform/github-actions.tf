########################################
# GitHub Actions 用 IAM 設定
########################################

# ============================================================
# 【パターン①】この AWS アカウントに GitHub OIDC Provider が
# まだ存在しない場合に使う（初回セットアップ用）
# ============================================================
#
resource "aws_iam_openid_connect_provider" "github" {
   url = "https://token.actions.githubusercontent.com"

   client_id_list = [
     "sts.amazonaws.com"
   ]

   thumbprint_list = [
     # GitHub OIDC の既知フィンガープリント
     "9e99a48a9960b14926bb7f3b02e22da0ecd4e50f"
   ]
 }

# ============================================
# 【パターン②】既に GitHub OIDC Provider が
# 他の Terraform / 手作業で作成済みの場合に使う
# ============================================
# → 既存の OIDC Provider を data で参照するだけ
#data "aws_iam_openid_connect_provider" "github" {
#  url = "https://token.actions.githubusercontent.com"
#}

########################################
# GitHub Actions から引き受けさせる IAM ロール
########################################
resource "aws_iam_role" "github_actions" {
  name = "devsecops-github-actions-role"

  # GitHub Actions の OIDC トークンを使って
  # sts:AssumeRoleWithWebIdentity できるようにするための信頼ポリシー
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
          #Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # aud: GitHub → AWS STS を呼び出していることをチェック
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            # sub: このリポジトリからのワークフローだけを許可
            # 例: repo:オーナー名/リポジトリ名:*
            "token.actions.githubusercontent.com:sub" = "repo:koheinomura-aq/owasp-devsecops-techblog-1:*"
          }
        }
      }
    ]
  })
}

########################################
# GitHub Actions に付与する権限
# （ECR への push + ECS のデプロイ更新）
########################################
resource "aws_iam_role_policy" "github_actions_policy" {
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR ログイン & イメージの push / pull
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
      # ECS サービスの更新（force-new-deployment など）
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
