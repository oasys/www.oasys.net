output "s3_url" {
  value = aws_s3_bucket.hugo.bucket_domain_name
}
