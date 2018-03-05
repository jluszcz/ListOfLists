# Sourced from environment variables named TF_VAR_${VAR_NAME}
variable "aws_acct_id" {}
variable "site_name" {}
variable "site_url" {}

variable "aws_region" {
  type = "string"
  default = "us-east-2"
}

provider "aws" {
  region = "${var.aws_region}"
}

provider "aws" {
  alias = "us_east_1"
  region = "us-east-1"
}

resource "aws_s3_bucket" "site" {
	bucket = "${var.site_url}"
	acl = "public-read"
	website {
	    index_document = "index.html"
	}
}

resource "aws_s3_bucket" "site_www" {
	bucket = "www.${var.site_url}"
	acl = "public-read"
	website {
	    redirect_all_requests_to = "${var.site_url}"
	}
}

resource "aws_s3_bucket_policy" "site_policy" {
	bucket = "${aws_s3_bucket.site.id}"
	policy = <<POLICY
{
	"Version":"2012-10-17",
	"Statement": [
		{
			"Sid":"PublicReadGetObject",
      	  	"Effect":"Allow",
  		  	"Principal": "*",
    		"Action": [
				"s3:GetObject"
			],
    		"Resource": [
				"arn:aws:s3:::${aws_s3_bucket.site.id}/*"
			]
  	  	}
	]
}
POLICY
}

resource "aws_s3_bucket_object" "favicon" {
	bucket = "${aws_s3_bucket.site.id}"
	key = "images/favicon.ico"
	source = "images/${var.site_name}.ico"
	etag = "${md5(file("images/${var.site_name}.ico"))}"
}

resource "aws_acm_certificate" "cert" {
  provider = "aws.us_east_1"
  domain_name = "${var.site_url}"
  subject_alternative_names = ["www.${var.site_url}"]
  validation_method = "DNS"
  tags {
    Name = "${var.site_name} Certificate"
  }
}

resource "aws_acm_certificate_validation" "cert" {
  provider = "aws.us_east_1"
  certificate_arn = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = [
    "${aws_route53_record.cert_validation.fqdn}",
    "${aws_route53_record.cert_validation_www.fqdn}"
  ]
}

resource "aws_route53_record" "cert_validation" {
  name = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${aws_route53_zone.zone.id}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl = 60
}

resource "aws_route53_record" "cert_validation_www" {
  name = "${aws_acm_certificate.cert.domain_validation_options.1.resource_record_name}"
  type = "${aws_acm_certificate.cert.domain_validation_options.1.resource_record_type}"
  zone_id = "${aws_route53_zone.zone.id}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.1.resource_record_value}"]
  ttl = 60
}

resource "aws_cloudfront_distribution" "site_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.site.bucket_domain_name}"
    origin_id = "site_bucket_origin"
  }

  enabled = true
  is_ipv6_enabled = true
  default_root_object = "index.html"

  aliases = ["www.${var.site_url}", "${var.site_url}"]

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "site_bucket_origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "${aws_acm_certificate.cert.arn}"
    minimum_protocol_version = "TLSv1"
    ssl_support_method = "sni-only"
  }
}

resource "aws_s3_bucket" "generator" {
	bucket = "${var.site_url}-generator"
}

resource "aws_s3_bucket_object" "index_template" {
	bucket = "${aws_s3_bucket.generator.id}"
	key = "index.template"
	source = "index.template"
	etag = "${md5(file("index.template"))}"
}

resource "aws_s3_bucket_object" "list" {
	bucket = "${aws_s3_bucket.generator.id}"
	key = "${var.site_name}.json"
	source = "${var.site_name}.json"
	etag = "${md5(file("${var.site_name}.json"))}"
}

resource "aws_route53_zone" "zone" {
	name = "${var.site_url}"
}

resource "aws_route53_record" "record" {
	zone_id = "${aws_route53_zone.zone.zone_id}"
	name = "${var.site_url}"
	type = "A"

	alias {
		name = "${aws_cloudfront_distribution.site_distribution.domain_name}"
    zone_id = "${aws_cloudfront_distribution.site_distribution.hosted_zone_id}"
		evaluate_target_health = false
	}
}

resource "aws_route53_record" "record_www" {
	zone_id = "${aws_route53_zone.zone.zone_id}"
	name = "www.${var.site_url}"
	type = "A"

	alias {
		name = "${aws_cloudfront_distribution.site_distribution.domain_name}"
		zone_id = "${aws_cloudfront_distribution.site_distribution.hosted_zone_id}"
		evaluate_target_health = false
  }
}

resource "aws_cloudwatch_log_group" "logs" {
    name = "/aws/lambda/${var.site_name}-generator"
    retention_in_days = "7"
}

data "aws_iam_policy_document" "assume_role_policy_document" {
    statement {
        principals {
            type = "Service"
            identifiers = ["lambda.amazonaws.com"]
        }
        actions = ["sts:AssumeRole"]
    }
}

resource "aws_iam_role" "lambda_role" {
    name = "lambda.${var.site_name}"
    assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy_document.json}"
}

data "aws_iam_policy_document" "cloudwatch_role_policy_document" {
    statement {
        actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:Describe*"]
        resources = ["arn:aws:logs:${var.aws_region}:${var.aws_acct_id}:*"]
    }
}

resource "aws_iam_policy" "cloudwatch_role_policy" {
    name = "cloudwatch.${var.site_name}"
    policy = "${data.aws_iam_policy_document.cloudwatch_role_policy_document.json}"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_role_attachment" {
    role = "${aws_iam_role.lambda_role.name}"
    policy_arn = "${aws_iam_policy.cloudwatch_role_policy.arn}"
}

data "aws_iam_policy_document" "s3_get_role_policy_document" {
    statement {
        actions = ["s3:GetObject"]
        resources = ["${aws_s3_bucket.generator.arn}/*"]
    }
}

resource "aws_iam_policy" "s3_get_role_policy" {
    name = "s3.get.${var.site_name}"
    policy = "${data.aws_iam_policy_document.s3_get_role_policy_document.json}"
}

resource "aws_iam_role_policy_attachment" "s3_get_role_attachment" {
    role = "${aws_iam_role.lambda_role.name}"
    policy_arn = "${aws_iam_policy.s3_get_role_policy.arn}"
}

data "aws_iam_policy_document" "s3_put_role_policy_document" {
    statement {
        actions = ["s3:PutObject"]
        resources = ["${aws_s3_bucket.site.arn}/index.html"]
    }
}

resource "aws_iam_policy" "s3_put_role_policy" {
    name = "s3.put.${var.site_name}"
    policy = "${data.aws_iam_policy_document.s3_put_role_policy_document.json}"
}

resource "aws_iam_role_policy_attachment" "s3_put_role_attachment" {
    role = "${aws_iam_role.lambda_role.name}"
    policy_arn = "${aws_iam_policy.s3_put_role_policy.arn}"
}

resource "aws_s3_bucket_notification" "generator_notification" {
	bucket = "${aws_s3_bucket.generator.id}"

	lambda_function {
		lambda_function_arn = "${aws_lambda_function.lambda.arn}"
		events = ["s3:ObjectCreated:Put"]
	}
}
resource "aws_lambda_permission" "generator_allow_bucket" {
	statement_id = "AllowExecutionFromS3Bucket"
	action = "lambda:InvokeFunction"
	function_name = "${aws_lambda_function.lambda.arn}"
	principal = "s3.amazonaws.com"
	source_arn = "${aws_s3_bucket.generator.arn}"
}

variable "lambda_filename" {
    type = "string"
    default = "generator.zip"
}

resource "aws_lambda_function" "lambda" {
    filename = "${var.lambda_filename}"
    function_name = "${var.site_name}-generator"
    role = "${aws_iam_role.lambda_role.arn}"
    handler = "generator.lambda_handler"
    source_code_hash = "${base64sha256(file("${var.lambda_filename}"))}"
    runtime = "python2.7"
    publish = "false"
    description = "Generate ${var.site_url}"

    environment {
        variables = {
            SITE = "${var.site_name}"
            SITE_URL = "${var.site_url}"
        }
    }
}
