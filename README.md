#  ListOfLists

ListOfLists can generate a static website, hosted on AWS in an S3 bucket, from a json file stored in Dropbox.

## Status

[![Build Status](https://travis-ci.org/jluszcz/ListOfLists.svg?branch=master)](https://travis-ci.org/jluszcz/ListOfLists)

## List JSON

```
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
```

## Setup

1. Set up this directory with `virtualenv .`
1. `source bin/activate`
1. `pip install -r requirements.txt`

## Update Site

### Helper Script

```
#!/usr/bin/env sh

export SITE="mysite"
export SITE_URL="$SITE.com"

export DB_ACCESS_KEY="1234ABCD"
export DB_FILE_PATH="/MyDirectory/$SITE.json"

export TF_VAR_aws_acct_id="123412341234"
export TF_VAR_site_name="$SITE"
export TF_VAR_site_url="$SITE_URL"
export TF_VAR_db_access_key="$DB_ACCESS_KEY"
export TF_VAR_db_file_path="$DB_FILE_PATH"

source bin/activate
```

### Update

1. `source helper`
1. `build.sh`
1. `terraform apply`
