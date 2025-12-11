# Account Hardening
# [Best Practice] Block S3 Public Access & Enforce Encryption

resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}

resource "aws_s3_account_public_access_block" "block_all" {
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
}
