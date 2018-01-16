# Sourced from environment variables named TF_VAR_${VAR_NAME}
variable "aws_acct_id" {}

variable "aws_region" {
    type = "string"
    default = "us-east-2"
}

provider "aws" {
    region = "${var.aws_region}"
}

data "aws_route53_zone" "website" {
  name = "burgerlist.co."
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.website.zone_id}"
  name    = "www.${data.aws_route53_zone.website.name}"
  type    = "A"
  ttl     = "300"
  records = ["10.0.0.1"]
}

resource "aws_s3_bucket" "burger_list_site" {
	bucket = "jluszcz-burger-list-site"
	acl = "public-read"
	website {
	    index_document = "index.html"
	}
}

resource "aws_s3_bucket_policy" "burger_list_site_policy" {
  bucket = "${aws_s3_bucket.burger_list_site.id}"
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
				"arn:aws:s3:::${aws_s3_bucket.burger_list_site.id}/*"
			]
  	  	}
	]
}
POLICY
}

resource "aws_s3_bucket_object" "burger_list_css" {
	bucket = "${aws_s3_bucket.burger_list_site.id}"
	key = "shoelace.css"
	content_type = "text/css"
	source = "shoelace.css"
	etag = "${md5(file("shoelace.css"))}"
}

resource "aws_s3_bucket_object" "burger_list_favicon" {
	bucket = "${aws_s3_bucket.burger_list_site.id}"
	key = "images/favicon.ico"
	source = "images/favicon.ico"
	etag = "${md5(file("images/favicon.ico"))}"
}

resource "aws_s3_bucket" "burger_list_generator" {
	bucket = "jluszcz-burger-list-generator"
}

resource "aws_s3_bucket_object" "burger_list_index_template" {
	bucket = "${aws_s3_bucket.burger_list_generator.id}"
	key = "index.template"
	source = "index.template"
	etag = "${md5(file("index.template"))}"
}

resource "aws_s3_bucket_object" "burger_list_list" {
	bucket = "${aws_s3_bucket.burger_list_generator.id}"
	key = "list.json"
	source = "list.json"
	etag = "${md5(file("list.json"))}"
}
