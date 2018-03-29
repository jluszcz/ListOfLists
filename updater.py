#!/usr/bin/env python

import argparse
import boto3
import dropbox
import hashlib
import httplib
import logging
import os
import tempfile

from botocore.exceptions import ClientError


def md5_file(file_name):
    with open(file_name, 'rb') as f:
        return hashlib.md5(f.read()).hexdigest()


def get_list_from_dropbox(dropbox_access_key, dropbox_file_path):
    dbx = dropbox.Dropbox(dropbox_access_key)

    list_file = tempfile.NamedTemporaryFile(delete=False)
    dbx.files_download_to_file(list_file.name, dropbox_file_path)

    md5 = md5_file(list_file.name)
    logging.debug('DB List MD5: %s', md5)

    return list_file.name, md5


def get_s3_etag(s3, bucket_name, object_name):
    obj = s3.Object(bucket_name, object_name)
    try:
        e_tag = obj.e_tag.strip('"')
    except ClientError as e:
        if e.response['Error']['Code'] == str(httplib.NOT_FOUND):
            logging.debug('%s not found', object_name)
            e_tag = None
        else:
            logging.exception('Error querying %s', object_name)
            raise

    logging.debug('S3 List e_tag: %s', e_tag)

    return e_tag


def upload_to_s3(s3, bucket_name, object_name, file_name):
    s3.Bucket(bucket_name).upload_file(file_name, object_name)


def try_update_list_file(site_url, site_name, dropbox_access_key, dropbox_file_path, force=False):
    s3 = boto3.resource('s3')
    s3_bucket_name = '%s-generator' % site_url
    s3_object_name = '%s.json' % site_name

    db_list_file, db_list_file_md5 = get_list_from_dropbox(dropbox_access_key, dropbox_file_path)
    s3_etag = get_s3_etag(s3, s3_bucket_name, s3_object_name)

    if db_list_file_md5 == s3_etag and not force:
        logging.info('%s is already up to date, skipping', s3_object_name)
    else:
        logging.info('Updating %s', s3_object_name)
        upload_to_s3(s3, s3_bucket_name, s3_object_name, db_list_file)


def parse_args():
    parser = argparse.ArgumentParser(description='List of lists website generator')
    parser.add_argument('--verbose', '-v', dest='verbose', action='store_true', help='If provided, log at DEBUG instead of INFO.')
    parser.add_argument('--force', action='store_true', help='Force an update to S3 even if the list is already up to date.')
    parser.add_argument('--site-name', default=os.environ.get('SITE'), help='Site name, i.e. foolist.')
    parser.add_argument('--site-url', default=os.environ.get('SITE_URL'), help='Site URL, i.e. foo.list.')
    parser.add_argument('--dropbox-access-key', default=os.environ.get('DB_ACCESS_KEY'),
                        help='Access key used to access Dropbox.')
    parser.add_argument('--dropbox-path', default=os.environ.get('DB_FILE_PATH'), help='Path of file in Dropbox.')

    args = parser.parse_args()

    def _validate_arg(arg, arg_name, var_name):
        if not arg:
            raise ValueError('%s or $%s is required' % (arg_name, var_name))

    _validate_arg(args.site_name, '--site-name', 'SITE')
    _validate_arg(args.site_url, '--site-url', 'SITE_URL')
    _validate_arg(args.dropbox_access_key, '--dropbox-access-key', 'DB_ACCESS_KEY')
    _validate_arg(args.dropbox_path, '--dropbox-path', 'DB_FILE_PATH')

    return args


def setup_logging(verbose=False):
    """Sets up logging using the default python logger, at INFO or DEBUG, depending on the value of verbose"""

    logger = logging.getLogger()
    logger.setLevel(logging.INFO if not verbose else logging.DEBUG)
    for module in ['boto3', 'botocore', 'dropbox', 's3transfer']:
        logging.getLogger(module).setLevel(logging.CRITICAL)


def lambda_handler(event, context):
    """Entry point for Lambda"""
    setup_logging()
    try_update_list_file(os.environ['SITE_URL'], os.environ['SITE'], os.environ['DB_ACCESS_KEY'], os.environ['DB_FILE_PATH'])


def main():
    """Entry point for running as a CLI"""
    args = parse_args()
    setup_logging(args.verbose)
    try_update_list_file(args.site_url, args.site_name, args.dropbox_access_key, args.dropbox_path, args.force)


if __name__ == '__main__':
    main()
