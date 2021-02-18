output "s3_url" {
  value = aws_s3_bucket.hugo.website_endpoint
}
