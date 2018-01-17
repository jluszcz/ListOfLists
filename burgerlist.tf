# Sourced from environment variables named TF_VAR_${VAR_NAME}
variable "aws_acct_id" {}

variable "aws_region" {
    type = "string"
    default = "us-east-2"
}

provider "aws" {
    region = "${var.aws_region}"
}

resource "aws_s3_bucket" "burgerlist_site" {
	bucket = "burgerlist.co"
	acl = "public-read"
	website {
	    index_document = "index.html"
	}
}

resource "aws_s3_bucket" "burgerlist_site_www" {
	bucket = "www.burgerlist.co"
	acl = "public-read"
	website {
	    redirect_all_requests_to = "burgerlist.co"
	}
}

resource "aws_s3_bucket_policy" "burgerlist_site_policy" {
	bucket = "${aws_s3_bucket.burgerlist_site.id}"
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
				"arn:aws:s3:::${aws_s3_bucket.burgerlist_site.id}/*"
			]
  	  	}
	]
}
POLICY
}

resource "aws_s3_bucket_object" "burgerlist_css" {
	bucket = "${aws_s3_bucket.burgerlist_site.id}"
	key = "shoelace.css"
	content_type = "text/css"
	source = "shoelace.css"
	etag = "${md5(file("shoelace.css"))}"
}

resource "aws_s3_bucket_object" "burgerlist_favicon" {
	bucket = "${aws_s3_bucket.burgerlist_site.id}"
	key = "images/favicon.ico"
	source = "images/favicon.ico"
	etag = "${md5(file("images/favicon.ico"))}"
}

resource "aws_s3_bucket" "burgerlist_generator" {
	bucket = "jluszcz-burgerlist-generator"
}

resource "aws_s3_bucket_object" "burgerlist_index_template" {
	bucket = "${aws_s3_bucket.burgerlist_generator.id}"
	key = "index.template"
	source = "index.template"
	etag = "${md5(file("index.template"))}"
}

resource "aws_s3_bucket_object" "burgerlist_list" {
	bucket = "${aws_s3_bucket.burgerlist_generator.id}"
	key = "list.json"
	source = "list.json"
	etag = "${md5(file("list.json"))}"
}

resource "aws_route53_zone" "burgerlist_zone" {
  name = "burgerlist.co"
  comment = "burgerlist"
}

/*
TODO 2018-01-16 For some reason I'm getting 400s adding these records, though they work in the console

resource "aws_route53_record" "burgerlist_record" {
  zone_id = "${aws_route53_zone.burgerlist_zone.zone_id}"
  name = "burgerlist.co"
  type = "A"

  alias {
	  name = "${aws_s3_bucket.burgerlist_site.website_domain}"
	  zone_id = "${aws_route53_zone.burgerlist_zone.zone_id}"
	  evaluate_target_health = true
  }
}

resource "aws_route53_record" "burgerlist_record_www" {
  zone_id = "${aws_route53_zone.burgerlist_zone.zone_id}"
  name = "www.burgerlist.co"
  type = "A"

  alias {
	  name = "${aws_s3_bucket.burgerlist_site.website_domain}"
	  zone_id = "${aws_route53_zone.burgerlist_zone.zone_id}"
	  evaluate_target_health = true
  }
}
*/

resource "aws_cloudwatch_log_group" "burgerlist_logs" {
    name = "/aws/lambda/burgerlist"
    retention_in_days = "7"
}

data "aws_iam_policy_document" "burgerlist_assume_role_policy_document" {
    statement {
        principals {
            type = "Service"
            identifiers = ["lambda.amazonaws.com"]
        }
        actions = ["sts:AssumeRole"]
    }
}

resource "aws_iam_role" "burgerlist_lambda_role" {
    name = "lambda.burgerlist"
    assume_role_policy = "${data.aws_iam_policy_document.burgerlist_assume_role_policy_document.json}"
}

data "aws_iam_policy_document" "burgerlist_cloudwatch_role_policy_document" {
    statement {
        actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:Describe*"]
        resources = ["arn:aws:logs:${var.aws_region}:${var.aws_acct_id}:*"]
    }
}

resource "aws_iam_policy" "burgerlist_cloudwatch_role_policy" {
    name = "cloudwatch.burgerlist"
    policy = "${data.aws_iam_policy_document.burgerlist_cloudwatch_role_policy_document.json}"
}

resource "aws_iam_role_policy_attachment" "burgerlist_cloudwatch_role_attachment" {
    role = "${aws_iam_role.burgerlist_lambda_role.name}"
    policy_arn = "${aws_iam_policy.burgerlist_cloudwatch_role_policy.arn}"
}

data "aws_iam_policy_document" "burgerlist_s3_get_role_policy_document" {
    statement {
        actions = ["s3:GetObject"]
        resources = ["${aws_s3_bucket.burgerlist_generator.arn}/*"]
    }
}

resource "aws_iam_policy" "burgerlist_s3_get_role_policy" {
    name = "s3.get.burgerlist"
    policy = "${data.aws_iam_policy_document.burgerlist_s3_get_role_policy_document.json}"
}

resource "aws_iam_role_policy_attachment" "burgerlist_s3_get_role_attachment" {
    role = "${aws_iam_role.burgerlist_lambda_role.name}"
    policy_arn = "${aws_iam_policy.burgerlist_s3_get_role_policy.arn}"
}

data "aws_iam_policy_document" "burgerlist_s3_put_role_policy_document" {
    statement {
        actions = ["s3:PutObject"]
        resources = ["${aws_s3_bucket.burgerlist_site.arn}/index.html"]
    }
}

resource "aws_iam_policy" "burgerlist_s3_put_role_policy" {
    name = "s3.put.burgerlist"
    policy = "${data.aws_iam_policy_document.burgerlist_s3_put_role_policy_document.json}"
}

resource "aws_iam_role_policy_attachment" "burgerlist_s3_put_role_attachment" {
    role = "${aws_iam_role.burgerlist_lambda_role.name}"
    policy_arn = "${aws_iam_policy.burgerlist_s3_put_role_policy.arn}"
}

resource "aws_s3_bucket_notification" "burgerlist_generator_notification" {
	bucket = "${aws_s3_bucket.burgerlist_generator.id}"

	lambda_function {
		lambda_function_arn = "${aws_lambda_function.burgerlist_lambda.arn}"
		events = ["s3:ObjectCreated:Put"]
	}
}
resource "aws_lambda_permission" "burgerlist_generator_allow_bucket" {
	statement_id = "AllowExecutionFromS3Bucket"
	action = "lambda:InvokeFunction"
	function_name = "${aws_lambda_function.burgerlist_lambda.arn}"
	principal = "s3.amazonaws.com"
	source_arn = "${aws_s3_bucket.burgerlist_generator.arn}"
}

variable "burgerlist_filename" {
    type = "string"
    default = "burgerlist.zip"
}

resource "aws_lambda_function" "burgerlist_lambda" {
    filename = "${var.burgerlist_filename}"
    function_name = "burgerlist"
    role = "${aws_iam_role.burgerlist_lambda_role.arn}"
    handler = "burgerlist.lambda_handler"
    source_code_hash = "${base64sha256(file("${var.burgerlist_filename}"))}"
    runtime = "python2.7"
    publish = "false"
    description = "Generate burgerlist.co"
}
