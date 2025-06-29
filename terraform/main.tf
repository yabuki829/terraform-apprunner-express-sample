# 1. AWSでリージョンは変数で定義した値を使うことを指定
provider "aws" {
  region = var.aws_region
}

# 2. ESRのリポジトリの作成
# この中にDocker imageをpush してApp runnerが使用する
resource "aws_ecr_repository" "express_app" {
  name = "express-apprunner"
}


＃ 3. Apprunnerの作成
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
これのおかげでApprunnerがECRからPullできるようになる。
resource "aws_iam_role_policy_attachment" "ecr_access_policy" {
  role       = aws_iam_role.apprunner_ecr_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
