#!/usr/bin/env python

import codecs
import jinja2
import json

def read_template():
    with open('index.template') as f:
        return jinja2.Template(f.read())

def read_burger_list():
    with open('list.json') as f:
        return json.load(f)

def write_index(template, burger_list):
    with codecs.open('index.html', 'w', 'utf-8') as f:
        f.write(template.render(burger_list=burger_list))

def main():
    template = read_template()
    burger_list = read_burger_list()
    write_index(template, burger_list)

if __name__ == '__main__':
    main()
