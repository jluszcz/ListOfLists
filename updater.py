#!/usr/bin/env python

import argparse
import boto3
import dropbox
import hashlib
import json
import logging
import os
import pytz
import tempfile

from botocore.exceptions import ClientError


def md5_file(file_name):
    with open(file_name, 'rb') as f:
        return hashlib.md5(f.read()).hexdigest()


def get_dropbox_metadata(dropbox, dropbox_file_path):
    """return last modified time"""
    file_metadata = dropbox.files_get_metadata(dropbox_file_path)

    last_modified_time = file_metadata.client_modified
    last_modified_time = last_modified_time.replace(tzinfo=pytz.UTC)
    logging.debug('%s last modified time: %s', dropbox_file_path, last_modified_time)

    return last_modified_time


def get_list_from_dropbox(dropbox, dropbox_file_path, minify=True):
    with tempfile.NamedTemporaryFile(delete=False) as lf:
        dropbox.files_download_to_file(lf.name, dropbox_file_path)

    if minify:
        with open(lf.name) as f:
            list_data = json.load(f)

        with tempfile.NamedTemporaryFile('w', delete=False) as lf_min:
            json.dump(list_data, lf_min, separators=(',', ':'))

        logging.debug('Minified %s to %s', lf.name, lf_min.name)
        lf = lf_min

    md5 = md5_file(lf.name)
    logging.debug('%s MD5: %s', dropbox_file_path, md5)

    return lf.name, md5


def get_s3_metadata(s3, bucket_name, object_name):
    """return etag, last modified time"""
    obj = s3.Object(bucket_name, object_name)
    try:
        e_tag = obj.e_tag.strip('"')
        last_modified_time = obj.last_modified
    except ClientError:
        logging.exception('Error querying for %s/%s', bucket_name, object_name)
        e_tag = None

    logging.debug('S3 List e_tag: %s, Last Modified Time: %s', e_tag, last_modified_time)

    return e_tag, last_modified_time


def upload_to_s3(s3, bucket_name, object_name, file_name):
    s3.Bucket(bucket_name).upload_file(file_name, object_name)


def try_update_list_file(site_url, site_name, dropbox_access_key, dropbox_file_path, force=False):
    s3 = boto3.resource('s3')
    s3_bucket_name = '%s-generator' % site_url
    s3_object_name = '%s.json' % site_name

    s3_etag, s3_last_modified_time = get_s3_metadata(s3, s3_bucket_name, s3_object_name)

    dbx = dropbox.Dropbox(dropbox_access_key)
    db_last_modified_time = get_dropbox_metadata(dbx, dropbox_file_path)

    if db_last_modified_time <= s3_last_modified_time and not force:
        logging.info('%s has not been modified since the last S3 upload, skipping', s3_object_name)
        return

    db_list_file, db_list_file_md5 = get_list_from_dropbox(dbx, dropbox_file_path)

    if db_list_file_md5 == s3_etag and not force:
        logging.info('%s is already up to date, skipping', s3_object_name)
    else:
        logging.info('Updating %s', s3_object_name)
        upload_to_s3(s3, s3_bucket_name, s3_object_name, db_list_file)


def parse_args():
    parser = argparse.ArgumentParser(description='List of lists website generator')
    parser.add_argument('--verbose', '-v', dest='verbose', action='store_true', help='If provided, log at DEBUG instead of INFO.')
    parser.add_argument('--force', '-f', dest='force', action='store_true',
                        help='Force an update to S3 even if the list is already up to date.')
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
    for module in ['boto3', 'botocore', 'dropbox', 's3transfer', 'urllib3']:
        logging.getLogger(module).setLevel(logging.CRITICAL if not verbose else logging.INFO)


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
