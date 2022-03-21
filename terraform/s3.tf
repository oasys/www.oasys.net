resource "aws_s3_bucket" "public" {
  bucket        = var.domain
  acl           = "public-read"
  force_destroy = true

  # checkov:skip=CKV_AWS_21:versioning not needed
  # checkov:skip=CKV_AWS_18:access logging disabled for cost savings
  # checkov:skip=CKV_AWS_19:encryption disabled, public bucket
  # checkov:skip=CKV_AWS_20:public bucket
  # checkov:skip=CKV_AWS_52:no MFA delete, not canonical source

  tags = merge(local.tags, {
    Name = "${var.domain} bucket"
  })
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.public.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }

  routing_rule {
    condition {
      key_prefix_equals = "/"
    }
    redirect {
      replace_key_prefix_with = "index.html"
    }
  }
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
