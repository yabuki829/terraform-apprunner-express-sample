# Express App with Prisma and App Runner (GitHub連携)

Express.jsアプリケーションをPrisma ORM + MySQL RDSでApp Runnerに**GitHub連携**でデプロイする手順

## 前提条件
- AWS CLIが設定済み
- Terraformがインストール済み
- GitHubリポジトリが作成済み

## デプロイ手順

### 1. コードをGitHubにプッシュ
```bash
git add .
git commit -m "Initial commit"
git push origin main
```

### 2. terraform.tfvarsファイル作成
```bash
cd terraform
cat > terraform.tfvars << EOF
github_repository_url = "https://github.com/your-username/your-repo"
db_password = "your-secure-password"
EOF
```

### 3. Terraformでインフラ構築
```bash
# 初回のみ
terraform init

# 確認
terraform plan

# デプロイ
terraform apply
```

### 4. GitHub Connection承認
1. AWS Console → App Runner → Connections
2. `github-connection` の状態を確認
3. 「Available」でない場合は手動で承認

## 自動デプロイ
mainブランチにコードをプッシュすると自動でデプロイされます:

```bash
# コード変更後
git add .
git commit -m "Update code"
git push origin main
# → App Runnerが自動ビルド&デプロイ
```

## 設定ファイル
- `apprunner.yaml`: App Runnerのビルド設定
- Prismaクライアント生成も自動実行

## API エンドポイント
- `GET /health` - ヘルスチェック
- `GET /products` - 商品一覧取得
- `POST /products` - 商品作成

## 商品作成例
```bash
curl -X POST https://your-app-url/products \
  -H "Content-Type: application/json" \
  -d '{"name":"サンプル商品","description":"説明","price":1000,"stock":10}'
```
