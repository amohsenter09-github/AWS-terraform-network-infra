resource "aws_s3_bucket" "bucket" {
  bucket = var.terraform_state_bucket
  tags = var.common_tags
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = var.terraform_state_dynamodb_name
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}