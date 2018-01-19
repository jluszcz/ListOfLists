#!/usr/bin/env sh

source bin/activate

CWD=$(pwd)
ZIP_NAME="$CWD/burgerlist.zip"

rm -f "$ZIP_NAME"
zip -9 "$ZIP_NAME"
pushd "lib/python2.7/site-packages"
zip -r9 "$ZIP_NAME" $(ls | grep -v boto)
popd
zip -g "$ZIP_NAME" burgerlist.py
