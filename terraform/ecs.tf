########################################
# ECR Repository（Juice Shop イメージ置き場）
########################################
resource "aws_ecr_repository" "juiceshop_repo" {
  name                 = "devsecops-juiceshop"
  image_tag_mutability = "MUTABLE" # タグ上書きを許可
  force_delete = true #削除時ECR内のイメージごと削除するよう設定

  image_scanning_configuration {
    scan_on_push = true # イメージ Push 時に脆弱性スキャンを実施
  }

  tags = {
    Name = "devsecops-juiceshop-repo"
  }
}

########################################
# ECS Cluster（コンテナの実行基盤）
########################################
resource "aws_ecs_cluster" "devsecops_cluster" {
  name = "devsecops-juiceshop-cluster"

  tags = {
    Name = "devsecops-juiceshop-cluster"
  }
}

##############################################
# IAM Roles（Fargate 用の実行ロール & タスクロール）
##############################################

# Fargate Execution Role
# → コンテナイメージの Pull / CloudWatch Logs への書き込みに必要
resource "aws_iam_role" "fargate_exec_role" {
  name = "devsecops-fargate-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Execution Role に付与するポリシー（ECR Pull & CloudWatch Logs）
resource "aws_iam_policy" "fargate_exec_policy" {
  name        = "devsecops-fargate-exec-policy"
  description = "Fargate が ECR / CloudWatch Logs にアクセスするためのポリシー"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR イメージ取得
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      # CloudWatch Logs 出力
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:ap-northeast-1:*:log-group:/ecs/devsecops-juiceshop*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_exec_attach" {
  role       = aws_iam_role.fargate_exec_role.name
  policy_arn = aws_iam_policy.fargate_exec_policy.arn
}

# ECS Task Role（アプリが AWS にアクセスする際に利用するロール）
# 今回Juice Shopは外部アクセス不要のため空だが作成は必須
resource "aws_iam_role" "fargate_task_role" {
  name = "devsecops-fargate-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

########################################
# ALB（内部向け）と Target Group
########################################

# 内部 ALB（インターネット非公開）
resource "aws_lb" "internal_alb" {
  name               = "devsecops-internal-alb"
  internal           = true # 内部ALBとして構築
  load_balancer_type = "application"
  subnets            = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_groups    = [aws_security_group.alb_sg.id]

  tags = {
    Name = "devsecops-internal-alb"
  }
}

# Staging環境Target Group
resource "aws_lb_target_group" "stg_tg" {
  name        = "devsecops-stg-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.devsecops_vpc.id
  target_type = "ip"

  health_check {
    path = "/rest/version" # Juice Shop のヘルスチェック
  }
}

# Production 環境 Target Group
resource "aws_lb_target_group" "prd_tg" {
  name        = "devsecops-prd-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.devsecops_vpc.id
  target_type = "ip"

  health_check {
    path = "/rest/version"
  }
}

########################################
# ALB Listeners
########################################

# Production Listener (80)
resource "aws_lb_listener" "prd_listener" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prd_tg.arn
  }
}

# Staging Listener (8080)
resource "aws_lb_listener" "stg_listener" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stg_tg.arn
  }
}

########################################
# Security Groups（ALB / Fargate）
########################################

# ALB Security Group（Bastion からのみアクセス可）
resource "aws_security_group" "alb_sg" {
  name        = "devsecops-alb-sg"
  vpc_id      = aws_vpc.devsecops_vpc.id

  # Bastion → ALB の HTTP/80 & 8080 を許可
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Fargate Security Group（ALB → Fargate のみ許可）
resource "aws_security_group" "fargate_sg" {
  name        = "devsecops-fargate-sg"
  vpc_id      = aws_vpc.devsecops_vpc.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################################
# ECS Task Definition（Juice Shop 共通タスク）
########################################

resource "aws_cloudwatch_log_group" "juiceshop_log_group" {
  name              = "/ecs/devsecops-juiceshop"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "juiceshop_task" {
  family                   = "devsecops-juiceshop-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.fargate_exec_role.arn
  task_role_arn            = aws_iam_role.fargate_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "juiceshop"
      image     = "${aws_ecr_repository.juiceshop_repo.repository_url}:latest" # GitHub Actions で毎回latest更新
      cpu       = 256
      memory    = 512
      essential = true

      portMappings = [{
        containerPort = 3000
        hostPort      = 3000
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.juiceshop_log_group.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

########################################
# ECS Services（Staging / Production）
########################################

# Staging (8080)
resource "aws_ecs_service" "stg_service" {
  name            = "stg-juiceshop"
  cluster         = aws_ecs_cluster.devsecops_cluster.name
  task_definition = aws_ecs_task_definition.juiceshop_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_c.id]
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.stg_tg.arn
    container_name   = "juiceshop"
    container_port   = 3000
  }

  force_new_deployment = true
}

# Production (80)
resource "aws_ecs_service" "prd_service" {
  name            = "prd-juiceshop"
  cluster         = aws_ecs_cluster.devsecops_cluster.name
  task_definition = aws_ecs_task_definition.juiceshop_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_c.id]
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prd_tg.arn
    container_name   = "juiceshop"
    container_port   = 3000
  }

  force_new_deployment = true
}
