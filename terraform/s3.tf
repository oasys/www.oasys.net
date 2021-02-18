resource "aws_s3_bucket" "public" {
  bucket        = var.domain
  acl           = "public-read"
  force_destroy = true

  website {
    index_document = "index.html"
    error_document = "404.html"

    routing_rules = jsonencode([{
      "Condition" : {
        "KeyPrefixEquals" : "/"
      },
      "Redirect" : {
        "ReplaceKeyWith" : "index.html"
      }
    }])
  }

  tags = merge(local.tags, {
    Name = "${var.domain} bucket"
  })
}

resource "aws_s3_bucket_policy" "public" {
  bucket = aws_s3_bucket.public.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "PublicRead",
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : "s3:GetObject",
        "Resource" : "arn:aws:s3:::${var.domain}/*"
      },
      {
        "Sid" : "PutWebsite",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : var.deploy_arn
        },
        "Action" : [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        "Resource" : "arn:aws:s3:::${var.domain}/*"
      }
    ]
  })
}
