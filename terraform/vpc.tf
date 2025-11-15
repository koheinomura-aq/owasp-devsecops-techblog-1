########################################
# VPC 基本設定
########################################
resource "aws_vpc" "devsecops_vpc" {
  cidr_block           = "10.0.0.0/16"        # 全体のアドレス範囲
  enable_dns_support   = true                # VPC内のDNSを有効化
  enable_dns_hostnames = true                # EC2などにDNSホスト名を付与

  tags = {
    Name = "devsecops-vpc"
  }
}

########################################
# プライベートサブネット
########################################

# ap-northeast-1a 用プライベートサブネット
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.devsecops_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false            # パブリックIPを割り当てない

  tags = {
    Name = "private-subnet-a"
  }
}

# ap-northeast-1c 用プライベートサブネット
resource "aws_subnet" "private_c" {
  vpc_id                  = aws_vpc.devsecops_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-c"
  }
}

########################################
# ルートテーブル（プライベート用）
########################################
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.devsecops_vpc.id

  tags = {
    Name = "private-rt"
  }
}

# ルートテーブルを各サブネットに関連付け
resource "aws_route_table_association" "private_a_assoc" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_c_assoc" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private_rt.id
}

############################################################
# VPC エンドポイント用セキュリティグループ（Interface 用）
############################################################
resource "aws_security_group" "vpce_sg" {
  name        = "vpce-interface-sg"
  description = "セキュリティグループ（各種インターフェース型VPCエンドポイント用）"
  vpc_id      = aws_vpc.devsecops_vpc.id

  # VPC 内部（10.0.0.0/16）からの HTTPS（443）アクセスを許可
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.devsecops_vpc.cidr_block]
  }

  # 全宛先へのアウトバウンドを許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpce-sg"
  }
}

########################################
# VPC エンドポイント群
########################################

# --- SSM 関連（EC2 の SSM 接続 & Session Manager 用）---
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.devsecops_vpc.id
  service_name        = "com.amazonaws.ap-northeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.devsecops_vpc.id
  service_name        = "com.amazonaws.ap-northeast-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.devsecops_vpc.id
  service_name        = "com.amazonaws.ap-northeast-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

# --- ECR 用（Fargate がコンテナイメージを Pull するために必須）---
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.devsecops_vpc.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.devsecops_vpc.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}

# --- S3 Gateway（ECRイメージ本体の取得など必須）---
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.devsecops_vpc.id
  service_name      = "com.amazonaws.ap-northeast-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]
}

# --- CloudWatch Logs（Fargate のログ出力用）---
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.devsecops_vpc.id
  service_name        = "com.amazonaws.ap-northeast-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}
