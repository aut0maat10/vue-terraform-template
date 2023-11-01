terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_s3_bucket" "web_app" {
  bucket = var.bucket_name
}

resource "aws_s3_account_public_access_block" "web_app" {
  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "web_app" {
  bucket       = aws_s3_bucket.web_app.id
  key          = "index.html"
  # source       = "index.html"
  content_type = "text/html"
}

resource "aws_cloudfront_distribution" "cdn_static_site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "my cloudfront distribution"

  origin {
    domain_name              = aws_s3_bucket.web_app.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  default_cache_behavior {
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  aliases = [ var.frontend_domain, var.www_frontend_domain ]

  viewer_certificate {
    #cloudfront_default_certificate = true 
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "cloudfront OAC"
  description                       = "description of OAC"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.cdn_static_site.domain_name
}

data "aws_iam_policy_document" "web_app" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.web_app.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.cdn_static_site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "web_app_policy" {
  bucket = aws_s3_bucket.web_app.id
  policy = data.aws_iam_policy_document.web_app.json
}

# create SSL certificate
resource "aws_acm_certificate" "cert" {
  #domain_name       = "*.${var.frontend_domain}"
  domain_name       = var.frontend_domain
  validation_method = "DNS"
  subject_alternative_names = [ var.www_frontend_domain ]

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "hosted_zone" {
  name         = var.frontend_domain
  private_zone = false
}

resource "aws_route53_record" "cert-cname" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.hosted_zone.zone_id
}

resource "aws_acm_certificate_validation" "validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert-cname : record.fqdn]
}

resource "aws_route53_record" "domain" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = var.frontend_domain
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.cdn_static_site.domain_name
    zone_id                = aws_cloudfront_distribution.cdn_static_site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "www.${var.frontend_domain}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.cdn_static_site.domain_name
    zone_id                = aws_cloudfront_distribution.cdn_static_site.hosted_zone_id
    evaluate_target_health = false
  }
}