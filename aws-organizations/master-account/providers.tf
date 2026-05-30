provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = "master"
      Project     = "pantri-organization"
      ManagedBy   = "terraform"
    }
  }
}