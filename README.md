# Pantri Organization Infrastructure as Code

AWS Organizationsを使用したマルチアカウント構成のInfrastructure as Codeプロジェクトです。開発環境（dev）と本番環境（prd）を管理アカウントから分離し、GitHub ActionsによるCI/CDパイプラインを実現します。

## アーキテクチャ概要

```
Organizations Root
├── Master Account (管理専用)
│   ├── OrganizationAccountAccessRole
│   ├── GitHub Actions用 OIDC Provider
│   └── Cross-Account Assume Roles
├── Dev Account
│   └── OrganizationAccountAccessRole
└── Prd Account
    └── OrganizationAccountAccessRole
```

### アカウント構成

- **Master Account**: AWS Organizations管理、IAM一元管理、請求管理
- **Dev Account**: 開発・テスト環境（Organizations管理対象）
- **Prd Account**: 本番環境（自動デプロイ）

## プロジェクト構成

```
pantri-organization-iac/
├── aws-organizations/          # AWS Organizations設定
│   ├── master-account/         # Master Account設定
│   │   ├── backend.tf          # Terraformバックエンド設定
│   │   ├── iam-oidc.tf         # GitHub Actions OIDC設定
│   │   ├── cross-account-roles.tf # クロスアカウントロール
│   │   ├── scp.tf              # Service Control Policy
│   │   ├── cloudtrail.tf       # 組織レベルCloudTrail
│   │   ├── providers.tf        # プロバイダー設定
│   │   ├── variables.tf        # 変数定義
│   │   ├── outputs.tf          # 出力値
│   │   └── versions.tf         # バージョン制約
│   └── account-setup/          # アカウント初期設定
│       ├── dev-account-setup.tf
│       ├── prd-account-setup.tf
│       └── common-setup.tf
└── .github/
    └── workflows/              # CI/CDワークフロー
```

## セキュリティ機能

### IAM管理戦略
- **OIDC Provider**: GitHub ActionsからのセキュアなAssumeRole
- **Cross-Account Roles**: アカウント間での最小権限アクセス
- **Role Chaining**: Master → Dev/Prd アカウントへの二段階認証

### セキュリティ強化
- **Service Control Policy (SCP)**: 本番環境での危険操作制限
- **Organization CloudTrail**: 全アカウントのAPI操作ログ
- **最小権限の原則**: 環境別の詳細な権限制御

## セットアップガイド

### 前提条件
- AWS Organizations の設定済み
- 3つのAWSアカウント（Master, Dev, Prd）
- GitHub リポジトリ

### GitHub設定

#### Variables
```
MASTER_ACCOUNT_ID: Master Account ID
DEV_ACCOUNT_ID: Dev Account ID
PRD_ACCOUNT_ID: Prd Account ID
```

#### Environments
特に設定不要（手動承認なし）

### 実装手順

1. **Master Account セットアップ**
   ```bash
   cd aws-organizations/master-account
   terraform init
   terraform plan
   terraform apply
   ```

2. **アカウント初期設定**
   ```bash
   cd aws-organizations/account-setup
   terraform init
   terraform plan
   terraform apply
   ```

## セキュリティベストプラクティス
- 組織レベルCloudTrail有効化
- SCP による本番環境保護
- マルチリージョン対応

## ブランチ戦略

- `main`: 変更を取りまとめるメインブランチ
- `prd`: 本番環境自動デプロイ
- `feature/*`: 機能開発ブランチ

## トラブルシューティング

### よくある問題
1. **AssumeRole権限エラー**: Trust Relationshipの確認
2. **SCP制限エラー**: ポリシー内容の確認
3. **OIDC認証失敗**: GitHub設定とThumbprintの確認

### ログ確認
- CloudTrail: API操作履歴
- GitHub Actions: ワークフロー実行ログ
- Terraform: plan/apply実行結果
