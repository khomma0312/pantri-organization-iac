# AWS Organizations マルチアカウント構成

## 概要

このプロジェクトでは、AWS Organizationsを使用したマルチアカウント構成を採用し、開発環境（dev）と本番環境（prd）を管理アカウントから分離します。GitHub ActionsからのAssumeRoleを使用した安全なCI/CDパイプラインを構築します。

## アカウント構成

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

### 各アカウントの役割

#### Master Account（管理アカウント）
- **用途**: AWS Organizations の管理、IAM の一元管理、請求管理
- **リソース**:
  - GitHub Actions用 OIDC Provider
  - クロスアカウント Assume Role の定義
  - Service Control Policy (SCP) の管理
  - CloudTrail Organization Trail
- **原則**: 実際のワークロードは配置しない

#### Dev Account（開発環境）
- **用途**: 開発・テスト環境のリソース
- **デプロイ**: このプロジェクトではデプロイ対象外（Organizations管理のみ）
- **特徴**: より自由度の高い権限設定

#### Prd Account（本番環境）
- **用途**: 本番環境のリソース
- **デプロイ**: `prd` ブランチへのマージで自動デプロイ
- **特徴**: 厳格な権限制限とSCPによる保護

## プロジェクトディレクトリ構成

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
    └── workflows/              # CI/CD設定
```

## IAM管理戦略

### 1. Master Account での OIDC Provider 設定

```hcl
# aws-organizations/master-account/iam-oidc.tf
resource "aws_iam_openid_connect_provider" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  
  tags = {
    Name = "GitHub Actions OIDC Provider"
    Environment = "master"
  }
}
```

### 2. GitHub Actions用ロール（環境別）

```hcl
# aws-organizations/master-account/cross-account-roles.tf

# GitHub Actions用ロール（開発環境）
resource "aws_iam_role" "github_actions_dev" {
  name = "GitHubActions-Dev-Role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = [
              "repo:your-org/pantri-iac:ref:refs/heads/main",
              "repo:your-org/pantri-iac:pull_request"
            ]
          }
        }
      }
    ]
  })
  
  tags = {
    Environment = "dev"
    Purpose = "GitHub Actions"
  }
}

# Dev Accountへのクロスアカウントロール引き受け権限
resource "aws_iam_role_policy" "github_actions_dev_policy" {
  name = "AssumeDevAccountRole"
  role = aws_iam_role.github_actions_dev.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = "arn:aws:iam::${var.dev_account_id}:role/TerraformExecutionRole"
      }
    ]
  })
}

# GitHub Actions用ロール（本番環境）
resource "aws_iam_role" "github_actions_prd" {
  name = "GitHubActions-Prd-Role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = [
              "repo:your-org/pantri-iac:ref:refs/heads/prd",
              "repo:your-org/pantri-iac:pull_request"
            ]
          }
        }
      }
    ]
  })
  
  tags = {
    Environment = "prd"
    Purpose = "GitHub Actions"
  }
}

# Prd Accountへのクロスアカウントロール引き受け権限
resource "aws_iam_role_policy" "github_actions_prd_policy" {
  name = "AssumePrdAccountRole"
  role = aws_iam_role.github_actions_prd.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = "arn:aws:iam::${var.prd_account_id}:role/TerraformExecutionRole"
      }
    ]
  })
}
```

### 3. 各アカウントでのTerraform実行ロール

```hcl
# aws-organizations/account-setup/dev-account-setup.tf
resource "aws_iam_role" "terraform_execution_role_dev" {
  provider = aws.dev
  name = "TerraformExecutionRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.master_account_id}:role/GitHubActions-Dev-Role"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Environment = "dev"
    Purpose = "Terraform Execution"
  }
}

# Dev環境用の権限ポリシー（開発環境なので比較的緩い権限）
resource "aws_iam_role_policy_attachment" "terraform_execution_dev_policy" {
  provider = aws.dev
  role = aws_iam_role.terraform_execution_role_dev.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# 追加で必要な権限（PowerUserAccessに含まれない権限）
resource "aws_iam_role_policy" "terraform_execution_dev_additional" {
  provider = aws.dev
  name = "TerraformAdditionalPermissions"
  role = aws_iam_role.terraform_execution_role_dev.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile"
        ]
        Resource = "*"
      }
    ]
  })
}

# aws-organizations/account-setup/prd-account-setup.tf
resource "aws_iam_role" "terraform_execution_role_prd" {
  provider = aws.prd
  name = "TerraformExecutionRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.master_account_id}:role/GitHubActions-Prd-Role"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })
  
  tags = {
    Environment = "prd"
    Purpose = "Terraform Execution"
  }
}

# 本番環境用のカスタム権限ポリシー（最小権限）
resource "aws_iam_role_policy" "terraform_execution_prd_policy" {
  provider = aws.prd
  name = "TerraformProductionPolicy"
  role = aws_iam_role.terraform_execution_role_prd.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # ECS関連
          "ecs:*",
          # ALB関連
          "elasticloadbalancing:*",
          # VPC関連
          "ec2:Describe*",
          "ec2:CreateVpc*",
          "ec2:CreateSubnet*",
          "ec2:CreateRoute*",
          "ec2:CreateSecurityGroup*",
          "ec2:AuthorizeSecurityGroup*",
          "ec2:RevokeSecurityGroup*",
          # RDS関連（削除系は除外）
          "rds:Create*",
          "rds:Describe*",
          "rds:Modify*",
          # S3関連（削除系は除外）
          "s3:Create*",
          "s3:Get*",
          "s3:List*",
          "s3:Put*"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## CI/CDワークフロー設計

### 1. PR作成時のPlan確認（全ブランチ）

```yaml
# .github/workflows/terraform-pr.yml
name: Terraform Plan on Pull Request

on:
  pull_request:
    branches: [main, prd]  # main, prdブランチへのPR時のみ実行
    paths:
      - 'aws-organizations/**'

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    environment: prd
    env:
      MASTER_ACCOUNT_ID: ${{ secrets.MASTER_ACCOUNT_ID }}
      IAM_DEPLOY_ROLE: ${{ vars.IAM_DEPLOY_ROLE }}
    permissions:
      id-token: write
      contents: read
      pull-requests: write
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      # 1. Master Accountの役割を引き受け
      - name: Configure AWS Credentials (Master)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.MASTER_ACCOUNT_ID }}:role/${{ env.IAM_DEPLOY_ROLE }}
          aws-region: ap-northeast-1
          role-session-name: GitHubActions-PR-Session
      
      # 2. Prd Accountの役割を引き受け（将来的にクロスアカウント対応時）
      # 現在はmaster-accountのみなので、この段階ではスキップ
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0
        
      - name: Terraform Init
        working-directory: aws-organizations/master-account
        run: terraform init
        
      - name: Terraform Format Check
        working-directory: aws-organizations/master-account
        run: terraform fmt -check
        
      - name: Terraform Validate
        working-directory: aws-organizations/master-account
        run: terraform validate
        
      - name: Terraform Plan
        working-directory: aws-organizations/master-account
        run: terraform plan -no-color > plan_output.txt
        continue-on-error: true
        
      - name: Comment PR with Plan
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const path = 'aws-organizations/master-account/plan_output.txt';
            
            let planOutput = '';
            try {
              planOutput = fs.readFileSync(path, 'utf8');
            } catch (error) {
              planOutput = 'Error reading plan output: ' + error.message;
            }
            
            // Truncate if too long (GitHub comment limit)
            if (planOutput.length > 60000) {
              planOutput = planOutput.substring(0, 60000) + '\n\n... (output truncated)';
            }
            
            const output = `
            ## Terraform Plan for Master Account 🚀
            
            **Target**: AWS Organizations Master Account Infrastructure
            **Base Branch**: \`${{ github.base_ref }}\`
            **Head Branch**: \`${{ github.head_ref }}\`
            
            <details>
            <summary>📋 Show Terraform Plan</summary>
            
            \`\`\`terraform
            ${planOutput}
            \`\`\`
            
            </details>
            
            ⚠️ **Warning**: This plan will affect the master account infrastructure if merged to the \`prd\` branch.
            
            ### Next Steps
            1. Review the plan output above
            2. Ensure all changes are expected
            3. If approved, merge this PR to deploy to production
            `;
            
            // 常に新しいコメントを作成
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: output
            });
```

### 2. 本番環境デプロイ（prd ブランチ）

```yaml
# .github/workflows/terraform-deploy.yml
name: Deploy to Production Environment

on:
  push:
    branches: [prd]
    paths:
      - 'aws-organizations/**'

jobs:
  terraform-prd:
    runs-on: ubuntu-latest
    environment: prd
    env:
      MASTER_ACCOUNT_ID: ${{ secrets.MASTER_ACCOUNT_ID }}
      IAM_DEPLOY_ROLE: ${{ vars.IAM_DEPLOY_ROLE }}
    permissions:
      id-token: write
      contents: read
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      # 1. Master Accountの役割を引き受け
      - name: Configure AWS Credentials (Master)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.MASTER_ACCOUNT_ID }}:role/${{ env.IAM_DEPLOY_ROLE }}
          aws-region: ap-northeast-1
          role-session-name: GitHubActions-Prd-Session
      
      # 2. 将来的にクロスアカウント対応時はここでPrd Accountの役割を引き受け
      # 現在はmaster-accountのみなので、この段階ではスキップ
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0
        
      - name: Terraform Init
        working-directory: aws-organizations/master-account
        run: terraform init
        
      - name: Terraform Format Check
        working-directory: aws-organizations/master-account
        run: terraform fmt -check
        
      - name: Terraform Validate
        working-directory: aws-organizations/master-account
        run: terraform validate
        
      - name: Terraform Plan
        working-directory: aws-organizations/master-account
        run: terraform plan -no-color
        
      - name: Terraform Apply
        if: github.ref == 'refs/heads/prd' && github.event_name == 'push'
        working-directory: aws-organizations/master-account
        run: terraform apply -auto-approve
        
      - name: Update Commit Status - Success
        if: success()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.repos.createCommitStatus({
              owner: context.repo.owner,
              repo: context.repo.repo,
              sha: context.sha,
              state: 'success',
              description: 'Master account deployment completed successfully',
              context: 'terraform/master-account'
            });
        
      - name: Update Commit Status - Failure
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.repos.createCommitStatus({
              owner: context.repo.owner,
              repo: context.repo.repo,
              sha: context.sha,
              state: 'failure',
              description: 'Master account deployment failed',
              context: 'terraform/master-account'
            });
```

## セキュリティベストプラクティス

### 1. Service Control Policy (SCP)

```hcl
# aws-organizations/master-account/scp.tf

# 本番環境用の制限ポリシー
resource "aws_organizations_policy" "prd_restrictions" {
  name = "ProductionEnvironmentRestrictions"
  description = "Security restrictions for production environment"
  type = "SERVICE_CONTROL_POLICY"
  
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "DenyDangerousActions"
        Effect = "Deny"
        Action = [
          "ec2:TerminateInstances",
          "rds:DeleteDBInstance",
          "rds:DeleteDBCluster",
          "s3:DeleteBucket",
          "iam:DeleteRole",
          "iam:DeleteUser"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalTag/Environment" = "production-admin"
          }
        }
      },
      {
        Sid = "DenyRootAccess"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Principal = {
          AWS = "arn:aws:iam::*:root"
        }
      }
    ]
  })
}

# 本番アカウントにSCPを適用
resource "aws_organizations_policy_attachment" "prd_restrictions_attachment" {
  policy_id = aws_organizations_policy.prd_restrictions.id
  target_id = var.prd_account_id
}
```

### 2. CloudTrail 組織レベル設定

```hcl
# aws-organizations/master-account/cloudtrail.tf

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "pantri-organization-cloudtrail-logs-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name = "Organization CloudTrail Logs"
    Environment = "master"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "organization_trail" {
  name = "pantri-organization-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.bucket
  is_organization_trail = true
  include_global_service_events = true
  is_multi_region_trail = true
  enable_logging = true
  
  event_selector {
    read_write_type = "All"
    include_management_events = true
    
    data_resource {
      type = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
  }
  
  tags = {
    Name = "Organization CloudTrail"
    Environment = "master"
  }
}
```

### 3. 最小権限の原則

#### 本番環境用の厳格な権限設定

```hcl
# aws-organizations/account-setup/prd-account-setup.tf
resource "aws_iam_role" "terraform_execution_role_prd" {
  provider = aws.prd
  name = "TerraformExecutionRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.master_account_id}:role/GitHubActions-Prd-Role"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })
  
  tags = {
    Environment = "prd"
    Purpose = "Terraform Execution"
  }
}

# 本番環境用のカスタム権限ポリシー（最小権限）
resource "aws_iam_role_policy" "terraform_execution_prd_policy" {
  provider = aws.prd
  name = "TerraformProductionPolicy"
  role = aws_iam_role.terraform_execution_role_prd.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # ECS関連
          "ecs:*",
          # ALB関連
          "elasticloadbalancing:*",
          # VPC関連
          "ec2:Describe*",
          "ec2:CreateVpc*",
          "ec2:CreateSubnet*",
          "ec2:CreateRoute*",
          "ec2:CreateSecurityGroup*",
          "ec2:AuthorizeSecurityGroup*",
          "ec2:RevokeSecurityGroup*",
          # RDS関連（削除系は除外）
          "rds:Create*",
          "rds:Describe*",
          "rds:Modify*",
          # S3関連（削除系は除外）
          "s3:Create*",
          "s3:Get*",
          "s3:List*",
          "s3:Put*"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## 実装順序

### Phase 1: Master Account セットアップ
1. AWS Organizations の設定
2. OIDC Provider の作成
3. GitHub Actions 用ロールの作成
4. CloudTrail 組織設定

### Phase 2: アカウント初期設定
1. 各アカウントでの Terraform 実行ロール作成
2. SCP の設定と適用
3. 基本的な監査設定

### Phase 3: CI/CD パイプライン構築
1. GitHub Actions ワークフローの作成
2. GitHub Variables の設定

### Phase 4: セキュリティ強化
1. 詳細な権限設定の調整
2. 監視・アラートの設定
3. セキュリティスキャンの統合

## 必要な GitHub Settings

### Environment Secrets (prd environment)
- `MASTER_ACCOUNT_ID`: Master Account ID

### Environment Variables (prd environment)  
- `IAM_DEPLOY_ROLE`: IAM role name for deployment (例: GitHubActions-Prd-Role)

### Environments
- `prd` environment の作成が必要
- 手動承認設定は任意

### Repository Settings
- Actions permissions: "Allow all actions and reusable workflows"
- Workflow permissions: "Read and write permissions"
