#!/usr/bin/python

'''
Author: Albert Monfa

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
'''

import os
import sys
import boto3
import botocore
import yaml
import logging
import logging.handlers
import argparse
from threading import Thread
from jinja2 import Template
from jsonschema import validate, ValidationError

global logger
threadpool = list()

nginx_vhost_tmpl = """
{% for site in sites %}\
server {

      listen              443 ssl http2;
      server_name         {{ site.server_name }};

      access_log  off;
      error_log on;

      ssl_certificate     {{ site.ssl_crt_file }};
      ssl_certificate_key {{ site.ssl_key_file }};
      ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
      ssl_ciphers         HIGH:!aNULL:!MD5;

      add_header Strict-Transport-Security "max-age=15768000; includeSubDomains" always;
      error_page  497 https://$host$request_uri;

      location / {
	 resolver {{ site.resolver }};
         set $backend {{ site.proxy_pass }};
         proxy_pass $backend;
         proxy_pass_header Server;
         proxy_set_header Host      $host;
         proxy_set_header x-realip $remote_addr;
         proxy_set_header x-forwarded-for $proxy_add_x_forwarded_for;

         proxy_request_buffering         off;
         proxy_max_temp_file_size          0;
         proxy_connect_timeout            30;
         proxy_read_timeout              120;
         proxy_intercept_errors          off;
      }
}

{% endfor %}
"""

# Constant subsystem
def constant(f):
    def fset(self, value):
        raise TypeError
    def fget(self):
        return f()
    return property(fget, fset)

class _Const(object):
    @constant
    def APP_NAME_DESC():
        return """
                This tool is designed to configure automatically SSL sites looking
                into a S3Bucket the certificate files, and writing the Nginx config.
                The Nginx configuration only can act as proxy server, using the
                proxy_pass Nginx capabilities.
               """
    @constant
    def APP_NAME():
        return 'ecs-wl-ssl-gateway'
    @constant
    def APP_USAGE():
        return """
        ecs-wl-ssl-gateway [-h] [--config file]

        To using ecs-wl-ssl-gateway you need define first a file configuration
        with read permissions. By default the aplications expect to
        find that file on /etc/nginx/sites-ssl-config.yml. An exemple of
        the yaml config file could be:

        ---
        global:
          bucket_name: "com.company-name.ops.ssl-certificates"
          nginx_ssl_path: "/etc/nginx/ssl-certs/"
          nginx_ssl_sites_config: "/etc/nginx/conf.d/web-ssl-proxy.conf"

        certificates:
          - wc.foo.com:
            server_name: "*.foo.com"
            certificate: "certificate.crt"
            certificate_key: "certificate.key"
            proxy_pass: "http://foo"
            resolver: "10.0.0.2" # DNS RESOLVER IN AWS VPC

        - wc.bar.com:
            server_name: "*.bar.com"
            certificate: "certificate.crt"
            certificate_key: "certificate.key"
            proxy_pass: "http://bar"
            resolver: "10.0.0.2"  # DNS RESOLVER IN AWS VPC

        ...

        You can add as many certificates as you need.
        """
    @constant
    def APP_EPILOG():
        return """
         ECS WhiteLabel SSL Gateway Autoconf - Albert Monfa 2018.
         This Software is released under Apache License, Version 2.0.
        """



class s3_downloader(Thread):
    s3_bucket = None
    s3_key = None
    dst = None
    session = None
    s3 = None

    failed = False

    def __init__(self, s3_bucket, s3_key, dst):
        Thread.__init__(self)
        self.s3_bucket = s3_bucket
        self.s3_key = s3_key
        self.dst = dst
        self.daemon = True
        self.start()

    def s3_key_exist(self):
        try:
            self.s3.Object(self.s3_bucket, self.s3_key).load()
            return True
        except botocore.exceptions.ClientError as e:
            self.failed = True
            if e.response['Error']['Code'] == "404":
                logger.fatal('S3 Object '+ str(self.s3_key) + ' in bucket ' \
                                + str(self.s3_bucket) + ' do not exist!'
                            )
            else:
                logger.fatal('S3 Object '+ str(self.s3_key) + ' in bucket '  \
                                + str(self.s3_bucket) + ' unhandled error: ' \
                                + str(e.message)
                            )
        except Exception as e:
            self.failed = True
            logger.fatal('Boto3 exception with message: '+str(e))
            return False

    def s3_download_file(self):
        if not self.s3_key_exist():
           return
        try:
            bucket = self.s3.Bucket(self.s3_bucket)
            with open(self.dst, 'wb') as data:
                 bucket.download_fileobj(self.s3_key, data)
        except Exception as e:
            logger.fatal('S3 Key problem Bucket '+ self.s3_bucket +\
                         ', Object: ' + self.s3_key + ' msg: '+str(e.message)
                        )
            self.failed = True

    def run(self):
        self.session = boto3.session.Session()
        self.s3 = self.session.resource('s3')
        self.s3_download_file()
        logger.info('Downloaded file from Bucket: '+ self.s3_bucket +\
                     ', Object: ' + self.s3_key + ' in ' + self.dst
                    )




def config_validator():
    global_sch  = {
        "type": "object",
        "required": [ "global", "certificates"],
        "properties" : {
            "global": {
                "type": "object",
                "required": ["bucket_name"],
            "properties": {
                "bucket_name":  { "type": "string" },
                "region": { "type": "string" },
                "nginx_ssl_path":  { "type": "string" },
                "nginx_ssl_sites_config":  { "type": "string" },
            },
                "additionalProperties": False
            },
            "certificates": {
                "type": "array"
            },
        },
    }
    certificate_sch  = {
       "type": "object",
       "required": [ "server_name","certificate","certificate_key"],
       "properties" : {
         "server_name":  { "type": "string" },
         "certificate":  { "type": "string" },
         "certificate_key":  { "type": "string" },
         "proxy_pass":  { "type": "string" },
         "resolver":  { "type": "string" },
       },
       "additionalProperties": False
    }
    try:
        validate(cfg,  global_sch)
        for certificate in cfg['certificates']:
            validate(dict(certificate).popitem()[1],  certificate_sch)
    except Exception as e:
        logger.fatal('Fatal error validating YaML conf: '+str(e.message))
        sys.exit(1)

def load_yaml_config( file ):
    try:
        with open(file, 'r') as yml_file:
             global cfg
             cfg = yaml.load(yml_file)
             config_validator()
    except Exception as e:
           logger.fatal('Error loading yaml file config, it seems broken or missing! file:'+ str(file))
           sys.exit(1)

def file_exists( file ):
    if os.path.exists( file ) and os.path.isfile( file ):
       return True
    return False

def nginx_ssl_path_exists( nginx_ssl_path ):
    if not os.path.exists( nginx_ssl_path ):
        logger.fatal("Error nginx_ssl_path especified in the config doesn't exist:"+ str(nginx_ssl_path))
        sys.exit(1)

def create_nginx_ssl_path_certificate( nginx_ssl_path, certificate_nginx_ssl_path ):
    if not os.path.exists( nginx_ssl_path ):
        logger.fatal("Error nginx_ssl_path especified in the config doesn't exist:"+ str(nginx_ssl_path))
        sys.exit(1)
    else:
        directory = nginx_ssl_path+certificate_nginx_ssl_path+'/'
        if not os.path.exists(directory):
            try:
                os.makedirs(directory)
            except Exception as e:
                logger.fatal(e.message)
                sys.exit(1)

def certificate_downloader(bucket_name, downloader_opts):
    for item in downloader_opts:
        s3_thread_downloader = s3_downloader(bucket_name, item['s3_key'], item['local_path'])
        threadpool.append(s3_thread_downloader)

def generate_config():
    sites = []
    nginx_ssl_path_exists(cfg['global']['nginx_ssl_path'])
    for certificate in cfg['certificates']:
        ssl_name = certificate.keys()[0]
        parameters = certificate[ssl_name]
        create_nginx_ssl_path_certificate(
            cfg['global']['nginx_ssl_path'],
            ssl_name
        )
        dst_path = cfg['global']['nginx_ssl_path'] + ssl_name
        downloader_opts = [
            {
                's3_key' : ssl_name + '/' + parameters['certificate'],
                'local_path' : dst_path + '/' + parameters['certificate']
            },
            {
                's3_key' : ssl_name + '/' + parameters['certificate_key'],
                'local_path' : dst_path + '/' + parameters['certificate_key']
            }
        ]
        certificate_downloader(cfg['global']['bucket_name'],
            downloader_opts
            )
        site = {
            "server_name"  : parameters['server_name'],
            "ssl_crt_file" : dst_path + '/' + parameters['certificate'],
            "ssl_key_file" : dst_path + '/' + parameters['certificate_key'],
            "proxy_pass"   : parameters['proxy_pass'],
            "resolver"     : parameters['resolver']
        }
        sites.append(site)
    jinja2_tmpl = Template(nginx_vhost_tmpl)
    try:
        with open(cfg['global']['nginx_ssl_sites_config'], 'w') as f:
            f.write(jinja2_tmpl.render(sites=sites))
        logger.info("JINJA2 TMPL - Configured nginx ssl sites file in: " \
                    + str(cfg['global']['nginx_ssl_sites_config'])
                    )
    except Exception as e:
        logger.fatal("JINJA2 TMPL PROBLEM: " + str(e))
        sys.exit(1)

def wait_to_complete():
    for thread in threadpool:
        thread.join()

def shutdown():
    for thread in threadpool:
        if thread.failed:
           logger.info("FAIL - Application exited with errors.")
           sys.exit(1)
    logger.info("SUCCESS - Application finished without errors")
    sys.exit(0)

def cli_args_builder():
    parser = argparse.ArgumentParser(
                                      prog=str(CONST.APP_NAME),
                                      usage=str(CONST.APP_USAGE),
                                      description=str(CONST.APP_NAME_DESC),
                                      epilog=str(CONST.APP_EPILOG)
                                    )
    parser.add_argument('--config', '-c',
                            dest='config_file',
                            default='/etc/nginx/sites-ssl-config.yml',
                            help='ecs-wl-ssl-gateway yaml config file.'
                        )
    return vars(parser.parse_args())



if __name__ == '__main__':
    CONST = _Const()
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.DEBUG)
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s -  %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    args = cli_args_builder()
    logger.info("Starting application 'ecs-wl-ssl-gateway' - Albert Monfa 2018")
    load_yaml_config(args['config_file'])
    generate_config()
    wait_to_complete()
    shutdown()
