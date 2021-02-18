output "website" {
  value = aws_cloudfront_distribution.dist.domain_name
}
