# Sourced from environment variables named TF_VAR_${VAR_NAME}
variable "aws_acct_id" {}

variable "aws_region" {
    type = "string"
    default = "us-east-2"
}

provider "aws" {
    region = "${var.aws_region}"
}

resource "aws_s3_bucket" "burger_list_site" {
	bucket = "jluszcz-burger-list-site"
	acl = "private"
	# acl = "public-read"
	website {
	    index_document = "index.html"
	}
}

/*
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
*/

resource "aws_s3_bucket_object" "burger_list_css" {
	bucket = "${aws_s3_bucket.burger_list_site.id}"
	key = "shoelace.css"
	source = "shoelace.css"
}

resource "aws_s3_bucket_object" "burger_list_favicon" {
	bucket = "${aws_s3_bucket.burger_list_site.id}"
	key = "images/favicon.ico"
	source = "images/favicon.ico"
}

resource "aws_s3_bucket" "burger_list_generator" {
	bucket = "jluszcz-burger-list-generator"
}

resource "aws_s3_bucket_object" "burger_list_index_template" {
	bucket = "${aws_s3_bucket.burger_list_generator.id}"
	key = "index.template"
	source = "index.template"
}

resource "aws_s3_bucket_object" "burger_list_list" {
	bucket = "${aws_s3_bucket.burger_list_generator.id}"
	key = "list.json"
	source = "list.json"
}
