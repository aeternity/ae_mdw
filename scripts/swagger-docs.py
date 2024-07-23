#!/usr/bin/env python3

import yaml
import os
import json
from glob import glob
from pathlib import Path

SWAGGER_DOCS_DIR = 'docs/swagger_v3/'
MDW_VERSION_FILE = 'AEMDW_VERSION'
SWAGGER_OUTPUT_DIR = 'priv/static/swagger'
PATH_PREFIX = os.getenv('PATH_PREFIX', '/mdw/v3')

# Read YAML file
schemas = {}
paths = {}
node_schemas = None
swagger = None
mdw_version = None

with open(os.path.join(SWAGGER_DOCS_DIR, 'base.yaml')) as base_stream:
    swagger = yaml.safe_load(base_stream)

with open(MDW_VERSION_FILE) as mdw_version_file:
    mdw_version = mdw_version_file.read().strip()

with open(os.path.join(SWAGGER_DOCS_DIR, 'node_oas3.yaml')) as node_stream:
    node_oas3 = yaml.safe_load(node_stream)
    node_schemas = node_oas3['components']['schemas']

for filepath in Path(SWAGGER_DOCS_DIR).glob("*.spec.yaml"):
    with open(filepath, 'r') as stream:
        data_loaded = yaml.safe_load(stream)
        schemas = {**schemas, **data_loaded['schemas']}
        paths = {**paths, **data_loaded['paths']}

sorted_dict = lambda d: dict(sorted(d.items()))

swagger['paths'] = sorted_dict(paths)
swagger['components']['schemas'] = sorted_dict({**swagger['components']['schemas'], **schemas})
swagger['info']['version'] = mdw_version
swagger['servers'][0]['url'] = PATH_PREFIX

with open(os.path.join(SWAGGER_OUTPUT_DIR, "swagger_v3.json"), 'w') as jsonfile:
  json.dump(swagger, jsonfile, indent=2)

with open(os.path.join(SWAGGER_OUTPUT_DIR, "swagger_v3.yaml"), 'w') as yamlfile:
  yamlfile.write(yaml.dump(swagger, default_flow_style=False, allow_unicode=True))
