#  ListOfLists

ListOfLists can generate a static website, hosted on AWS in an S3 bucket, from a json file.

## Status

[![Build Status](https://travis-ci.org/jluszcz/ListOfLists.svg?branch=master)](https://travis-ci.org/jluszcz/ListOfLists)

## List JSON

    {
        "title": "The List",
        "lists": [
            {
                "title": "Letters",
                "hidden": true,
                "list": [
                    "A",
                    "B",
                    "C"
                ]
            },
            {
                "title": "Numbers",
                "list": [
                    "1",
                    "2",
                    "3"
                ]
            }
        ]
    }

## Setup

1. Set up this directory with `virtualenv .`
1. `source bin/activate`
1. `pip install -r requirements.txt`

## Update Site

### Helper Script

    #!/usr/bin/env sh

    export TF_VAR_aws_acct_id="123412341234"
    export TF_VAR_site_name="mysite"
    export TF_VAR_site_url="mysite.com"

    export SITE=${TF_VAR_site_name}
    export SITE_URL=${TF_VAR_site_url}

    source bin/activate

### Update

1. `source helper`
1. `build.sh`
1. `terraform apply`
