### 本リポジトリは[**手を動かして学ぶOWASP DevSecOps Guideline - 第1回：CI/CD基盤構築編**](公開後記事リンクを貼る)の検証で使うソースコード一式が含まれています。

## ディレクトリ構成

```
wasp-devsecops-techblog-1/       # プロジェクトルート
├─ README.md                   
├─ .gitignore
├─ terraform/
│   ├─ provider.tf               # provider設定・Terraformバージョン
│   ├─ network.tf                # VPC / サブネット / RT / VPCエンドポイント
│   ├─ bastion.tf                # 踏み台EC2・SSM用IAMロール・SG・AMI
│   ├─ ecs_ecr_alb.tf            # ECR / ECS / ALB / タスク定義 / SG Service
│   ├─ github-actions.tf         # GitHub OIDC / Actions用IAMロール
|   ├─ variables.tf              # 変数ファイル
│   ├─ outputs.tf                # リソースの出力値
|   └─ terraform.tfvars.example  # 環境変数ファイルのテンプレート
│
└─ .github/
    └─ workflows/
        ├─ deploy-stg.yml        # ステージングデプロイ用GitHub Actionsワークフロー
        └─ deploy-prd.yml        # 本番デプロイ用GitHub Actionsワークフロー
```

## Terraformで構成される主なリソース

- ECS Fargate（Staging / Production）
- Internal Application Load Balancer
- Bastion(EC2)
- VPC Endpoints

## Terraform使用方法

### 1.事前準備

本リポジトリをクローンし、Terraform を実行可能な環境を用意してください。

```
git clone https://github.com/<your-account>/owasp-devsecops-techblog-1.git
cd owasp-devsecops-techblog-1
```
Terraform のバージョンは以下を前提としています。

- Terraform: 1.13.5

- AWS Provider: 6.x

### 2.変数ファイルの準備

GitHub Actionsの OIDC 制御に利用するため、
実行するGitHubリポジトリ情報を terraform.tfvars に設定します。

```
cp terraform.tfvars.example terraform.tfvars
```

terraform.tfvars を編集し、以下を自分のリポジトリに合わせて設定します。
```
github_repo_owner = "your-github-username"
github_repo_name  = "your-repository-name"
```

### 3.Terraformの実行

Terraform を初期化し、インフラをデプロイします。

```
terraform init
terraform apply
```

内容を確認し、問題なければyesを入力してください。

## .github/workflowsについて

本ディレクトリには、検証で使用するGitHub Actionsのワークフローが含まれています。

- ステージング環境用デプロイ

- 本番環境用デプロイ

本検証では、環境ごとに特別な設定変更は不要です。

## 補足

- 本構成は検証用途を目的としたものです
