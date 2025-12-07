##############################
# 踏み台サーバ（Bastion）用IAMロール
##############################
resource "aws_iam_role" "bastion" {
  name = "devsecops-bastion-ssm-role"

  # EC2がこのロールを引き受ける（AssumeRole）ためのポリシー
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# SSM(セッションマネージャー)利用に必要なAWS管理ポリシーを付与
resource "aws_iam_role_policy_attachment" "bastion" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2に紐付けるInstance Profile（IAMロールをEC2に渡すための箱）
resource "aws_iam_instance_profile" "bastion" {
  name = "devsecops-bastion-instance-profile"
  role = aws_iam_role.bastion.name
}

###################################
# 踏み台サーバ用セキュリティグループ
###################################
resource "aws_security_group" "bastion" {
  name        = "devsecops-bastion-sg"
  description = "Security group for bastion EC2 (SSM + internal traffic)"
  vpc_id      = aws_vpc.devsecops.id

  # VPC 内部（10.0.0.0/16）からの TCP 通信をすべて許可
  # → ECS や内部リソースへ接続するため
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.devsecops.cidr_block]
  }

  # アウトバウンドはすべて許可（VPC エンドポイント経由で外部に出る）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devsecops-bastion-sg"
  }
}

#####################################
# 踏み台EC2インスタンス（Amazon Linux 2023）
#####################################
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023_latest.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_a.id          # プライベートサブネットに配置
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = false                             # インターネット非公開

  tags = {
    Name = "devsecops-bastion-ec2"
  }
}

######################################
# Amazon Linux 2023 の最新 AMI を取得
######################################
data "aws_ami" "al2023_latest" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  owners = ["137112412989"] # Amazon Linux AMI の公式アカウント
}
