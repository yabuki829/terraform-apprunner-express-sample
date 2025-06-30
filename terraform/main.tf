# 1. AWSでリージョンは変数で定義した値を使うことを指定
provider "aws" {
  region = var.aws_region
}

# 2. ESRのリポジトリの作成
# この中にDocker imageをpush してApp runnerが使用する
resource "aws_ecr_repository" "express_app" {
  name = "express-apprunner"
}


# 3. Apprunnerの作成
resource "aws_apprunner_service" "express_service" {
  # サービス名の設定
  service_name = "express-apprunner"

  # App Runner が ECR にアクセスするための IAM ロールを指定。
  # 4で設定したIAMロールを指定 
  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }

    # App Runner が使う Docker イメージの起動ポートを 3000 に指定。
    image_repository {
      image_configuration {
        port = "3000"
      }
      # App Runner が使用するイメージ（latestタグ）を指定。
      # 上で作成した express_app のリポジトリを参照。
      image_identifier      = "${aws_ecr_repository.express_app.repository_url}:latest"
      image_repository_type = "ECR"
    }

    # ECR イメージが更新されたら App Runner が自動デプロイするかどうか（true = 有効）。
    auto_deployments_enabled = true
  }

  # App Runner のインスタンスリソース指定。
  # CPU：512（= 0.5 vCPU）、メモリ：1024MB（= 1GB）。
  instance_configuration {
    cpu    = "512"
    memory = "1024"
  }

  # VPC接続設定
  network_configuration {
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.main.arn
    }
  }

  lifecycle {
    ignore_changes = [source_configuration[0].image_repository[0].image_identifier]
  }

  depends_on = [aws_apprunner_vpc_connector.main]
}

# 4. apprunnerがECS位アクセスするための権限 IAM ロールを作成
resource "aws_iam_role" "apprunner_ecr_access" {
  name = "AppRunnerECRAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "build.apprunner.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}


# 5.IAM ロールにポリシーを付与
# これのおかげでApprunnerがECRからPullできるようになる。
resource "aws_iam_role_policy_attachment" "ecr_access_policy" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}



# -----------------------------
# 1. VPC と サブネットの作成
# -----------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}c"
  map_public_ip_on_launch = false
}

# -----------------------------
# 2. セキュリティグループ
# -----------------------------
resource "aws_security_group" "rds_sg" {
  name   = "rds_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # App Runner からのアクセスを許可
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------
# 3. RDS インスタンス
# -----------------------------
resource "aws_db_subnet_group" "default" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

resource "aws_db_instance" "mysql" {
  identifier         = "apprunner-db"
  engine             = "mysql"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  username           = "admin"
  password           = var.db_password
  db_subnet_group_name = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot = true
  publicly_accessible = false
}

# -----------------------------
# 4. App Runner 用 VPC Connector
# -----------------------------
resource "aws_apprunner_vpc_connector" "main" {
  vpc_connector_name = "apprunner-vpc-connector"
  subnets            = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  security_groups    = [aws_security_group.rds_sg.id]
}

