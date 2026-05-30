terraform {
  backend "s3" {
    # S3バケット名は環境変数またはterraform initで指定
    # bucket = "pantri-terraform-state-{account-id}"
    # key    = "master-account/terraform.tfstate"
    # region = "ap-northeast-1"
    
    # DynamoDBテーブル名は環境変数またはterraform initで指定
    # dynamodb_table = "pantri-terraform-locks"
    
    # 状態ファイルの暗号化
    encrypt = true
  }
}