# 1. AWSでリージョンは変数で定義した値を使うことを指定
provider "aws" {
  region = var.aws_region
}

# 2. GitHub Connection for App Runner
resource "aws_apprunner_connection" "github_connection" {
  connection_name = "github-connection"
  provider_type   = "GITHUB"
}


# 3. Apprunnerの作成
resource "aws_apprunner_service" "express_service" {
  # サービス名の設定
  service_name = "express-apprunner"

  source_configuration {
    authentication_configuration {
      connection_arn = aws_apprunner_connection.github_connection.arn
    }

    code_repository {
      repository_url = var.github_repository_url
      
      source_code_version {
        type  = "BRANCH"
        value = "main"
      }

      code_configuration {
        configuration_source = "API"
        
        code_configuration_values {
          runtime                 = "NODEJS_18"
          build_command          = "npm install && npx prisma generate && npx prisma db push && npx prisma db seed && npm run build"
          start_command          = "npm start"
          runtime_environment_variables = {
            DATABASE_URL = "mysql://admin:${var.db_password}@${aws_db_instance.mysql.endpoint}/apprunner_db"
          }
        }
      }
    }

    auto_deployments_enabled = true
  }

  # App Runner のインスタンスリソース指定。
  # CPU：512（= 0.5 vCPU）、メモリ：1024MB（= 1GB）。
  instance_configuration {
    cpu    = "512"
    memory = "1024"
    
    # 環境変数の設定
    instance_role_arn = aws_iam_role.apprunner_instance_role.arn
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
  engine_version     = "8.0"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  db_name            = "apprunner_db"
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

# -----------------------------
# 5. App Runner Instance Role
# -----------------------------
resource "aws_iam_role" "apprunner_instance_role" {
  name = "AppRunnerInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "tasks.apprunner.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

