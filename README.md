# terraform App Runner

aws sts get-caller-identity  でuser_id を確認

## ECRにpushする

# 再ビルド
docker build -t express-apprunner .

# タグ付け（your-account-idは適宜変更）
docker tag express-apprunner:latest {id}.dkr.ecr.ap-northeast-1.amazonaws.com/express-apprunner:latest

# Push　AWSに反映
docker push {id}.dkr.ecr.ap-northeast-1.amazonaws.com/express-apprunner:latest

認証が切れていれば

このログイントークンの有効期限は 12時間 程度です。時間が空いた場合は再ログインが必要です。
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin {id}.dkr.ecr.ap-northeast-1.amazonaws.com


cd terraform
terraform plan
terraform apply
