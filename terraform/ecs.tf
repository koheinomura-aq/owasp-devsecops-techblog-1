########################################
# ECR Repository（Juice Shopイメージ置き場）
########################################
resource "aws_ecr_repository" "juiceshop" {
  name                 = "devsecops-juiceshop"
  image_tag_mutability = "MUTABLE" 
  force_delete = true #削除時ECR内のイメージごと削除するよう設定

  image_scanning_configuration {
    scan_on_push = true # イメージPush時に脆弱性スキャンを実施
  }

  tags = {
    Name = "devsecops-juiceshop-repo"
  }
}

########################################
# ECS Cluster（コンテナの実行基盤）
########################################
resource "aws_ecs_cluster" "devsecops" {
  name = "devsecops-juiceshop-cluster"

  tags = {
    Name = "devsecops-juiceshop-cluster"
  }
}

##############################################
# IAM Roles（Fargate用の実行ロール & タスクロール）
##############################################

# Fargate Execution Role
# → コンテナイメージの Pull / CloudWatch Logsへの書き込みに必要
resource "aws_iam_role" "fargate_exec" {
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

# Execution Roleに付与するポリシー（ECR Pull & CloudWatch Logs）
resource "aws_iam_policy" "fargate_exec" {
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
      # CloudWatch Logs出力
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

resource "aws_iam_role_policy_attachment" "fargate_exec" {
  role       = aws_iam_role.fargate_exec.name
  policy_arn = aws_iam_policy.fargate_exec.arn
}

# ECS Task Role（アプリがAWSにアクセスする際に利用するロール）
# 今回Juice Shopは外部アクセス不要のため空だが作成は必須
resource "aws_iam_role" "fargate_task" {
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
# ALB（内部向け）とTarget Group
########################################

# 内部 ALB（インターネット非公開）
resource "aws_lb" "internal" {
  name               = "devsecops-internal-alb"
  internal           = true # 内部ALBとして構築
  load_balancer_type = "application"
  subnets            = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_groups    = [aws_security_group.alb.id]

  tags = {
    Name = "devsecops-internal-alb"
  }
}

# Staging環境Target Group
resource "aws_lb_target_group" "stg" {
  name        = "devsecops-stg-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.devsecops_vpc.id
  target_type = "ip"

  health_check {
    path = "/rest/version" # Juice Shopのヘルスチェック
  }
}

# Production環境Target Group
resource "aws_lb_target_group" "prd" {
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
resource "aws_lb_listener" "prd" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prd.arn
  }
}

# Staging Listener (8080)
resource "aws_lb_listener" "stg" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stg.arn
  }
}

########################################
# Security Groups（ALB / Fargate）
########################################

# ALB Security Group（Bastionからのみアクセス可）
resource "aws_security_group" "alb" {
  name        = "devsecops-alb-sg"
  vpc_id      = aws_vpc.devsecops_vpc.id

  # Bastion → ALBのHTTP/80 & 8080を許可
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Fargate Security Group（ALB → Fargateのみ許可）
resource "aws_security_group" "fargate" {
  name        = "devsecops-fargate-sg"
  vpc_id      = aws_vpc.devsecops_vpc.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################################
# ECS Task Definition（Juice Shop共通タスク）
########################################

resource "aws_cloudwatch_log_group" "juiceshop" {
  name              = "/ecs/devsecops-juiceshop"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "juiceshop" {
  family                   = "devsecops-juiceshop-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.fargate_exec.arn
  task_role_arn            = aws_iam_role.fargate_task.arn

  container_definitions = jsonencode([
    {
      name      = "juiceshop"
      image     = "${aws_ecr_repository.juiceshop.repository_url}:latest" # GitHub Actions で毎回latest更新
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
          "awslogs-group"         = aws_cloudwatch_log_group.juiceshop.name
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
resource "aws_ecs_service" "stg" {
  name            = "stg-juiceshop"
  cluster         = aws_ecs_cluster.devsecops.name
  task_definition = aws_ecs_task_definition.juiceshop.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_c.id]
    security_groups = [aws_security_group.fargate.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.stg.arn
    container_name   = "juiceshop"
    container_port   = 3000
  }

  force_new_deployment = true
}

# Production (80)
resource "aws_ecs_service" "prd" {
  name            = "prd-juiceshop"
  cluster         = aws_ecs_cluster.devsecops.name
  task_definition = aws_ecs_task_definition.juiceshop.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_c.id]
    security_groups = [aws_security_group.fargate.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prd.arn
    container_name   = "juiceshop"
    container_port   = 3000
  }

  force_new_deployment = true
}
