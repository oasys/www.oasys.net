output "website" {
  value = aws_cloudfront_distribution.dist.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.dist.id
}
