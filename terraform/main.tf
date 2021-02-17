provider "aws" {
  region = "us-east-1"
}

locals {
  bucket_name = "blog-test.oasys.net"
}

resource "aws_s3_bucket" "hugo" {
  bucket        = local.bucket_name
  acl           = "public-read"
  force_destroy = true

  website {
    index_document = "index.html"
    error_document = "404.html"

    routing_rules = <<EOF
[{
  "Condition": {
      "KeyPrefixEquals": "/"
  },
  "Redirect": {
      "ReplaceKeyWith": "index.html"
  }
}]
EOF
  }
}

resource "aws_s3_bucket_policy" "hugo" {
  bucket = aws_s3_bucket.hugo.id
  policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement" : [
    {
      "Sid" : "PublicRead",
      "Effect" : "Allow",
      "Principal" : "*",
      "Action" : "s3:GetObject",
      "Resource" : "arn:aws:s3:::${local.bucket_name}/public/*"
    },
    {
      "Sid" : "PutWebsite",
      "Effect" : "Allow",
      "Principal" : {
        "AWS" : ["${var.deploy_arn}"]
      },
      "Action" : [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource" : "arn:aws:s3:::${local.bucket_name}/public/*"
    }
  ]
}
EOF
}
