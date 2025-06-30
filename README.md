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

## 踏み台サーバー経由でのデータベースアクセス

### 1. SSH鍵ペア生成
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bastion_key -N ""
```

### 2. terraform.tfvarsにSSH公開鍵を追加
```bash
cd terraform
cat ~/.ssh/bastion_key.pub   
ssh_public_keyに値を設定
```

### 3. 踏み台サーバーを含めてデプロイ
```bash
terraform plan
terraform apply
```

### 4. 踏み台サーバーにSSH接続
```bash
# 踏み台サーバーのパブリックIPを確認
terraform output bastion_public_ip

# SSH接続
ssh -i ~/.ssh/bastion_key ec2-user@{bastion_public_ip}
```

### 5. 踏み台サーバーからRDSに接続
```bash
# RDSエンドポイントを確認
echo "RDS_ENDPOINT=$(terraform output rds_endpoint)"

# MySQL接続
mysql -h {rds_endpoint} -u admin -p apprunner_db
# パスワード: terraform.tfvarsのdb_password
```

### 6. SSH Tunneling経由でローカルからRDSアクセス
```bash
# ローカルPCから
ssh -i ~/.ssh/bastion_key -L 3306:{rds_endpoint}:3306 ec2-user@{bastion_public_ip}

# 別ターミナルでローカルから接続
mysql -h 127.0.0.1 -P 3306 -u admin -p apprunner_db
```

### 7. データ投入例
```sql
-- 商品データ投入
INSERT INTO Product (name, description, price, stock) VALUES
('iPhone 15', '最新のiPhone', 128000, 10),
('MacBook Pro', 'M3チップ搭載', 248000, 5),
('AirPods Pro', 'ノイズキャンセリング機能付き', 39800, 20);

-- データ確認
SELECT * FROM Product;
```

## セキュリティ注意事項
- 踏み台サーバーは作業完了後に削除推奨
- SSH鍵は適切に管理
- 本番環境では踏み台サーバーへのアクセスIPを制限
