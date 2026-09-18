resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = false
  tags          = { Name = var.bucket_name }
}
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_object" "test" {
  bucket                 = aws_s3_bucket.this.id
  key                    = "test/hello.txt"
  content                = "AWS network lab: S3 healthy\n"
  content_type           = "text/plain"
  server_side_encryption = "AES256"
  depends_on             = [aws_s3_bucket_public_access_block.this, aws_s3_bucket_server_side_encryption_configuration.this]
}
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "DenyInsecureTransport", Effect = "Deny", Principal = "*", Action = "s3:*",
    Resource = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } },
    { Sid = "InstanceReadsMustUseLabEndpoints", Effect = "Deny", Principal = "*", Action = ["s3:GetObject"],
      Resource = "${aws_s3_bucket.this.arn}/test/hello.txt", Condition = {
        ArnEquals = { "aws:PrincipalArn" = var.role_arns }, StringNotEquals = { "aws:SourceVpce" = var.endpoint_ids }
      }
    }
  ] })
  depends_on = [aws_s3_bucket_public_access_block.this]
}
output "bucket_name" { value = aws_s3_bucket.this.id }
