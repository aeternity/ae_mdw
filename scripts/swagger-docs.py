#!/usr/bin/env python3

import yaml
import os
import json
from glob import glob
from pathlib import Path

SWAGGER_DOCS_DIR = 'docs/swagger_v3/'
MDW_VERSION_FILE = 'AEMDW_VERSION'
SWAGGER_OUTPUT_DIR = 'priv/static/swagger'

# Read YAML file
schemas = {}
paths = {}
swagger = None
mdw_version = None

with open(os.path.join(SWAGGER_DOCS_DIR, 'base.yaml')) as base_stream:
    swagger = yaml.safe_load(base_stream)

with open(MDW_VERSION_FILE) as mdw_version_file:
    mdw_version = mdw_version_file.read().strip()

for filepath in Path(SWAGGER_DOCS_DIR).glob("*.spec.yaml"):
    with open(filepath, 'r') as stream:
        data_loaded = yaml.safe_load(stream)
        schemas = {**schemas, **data_loaded['schemas']}
        paths = {**paths, **data_loaded['paths']}

swagger['paths'] = paths
swagger['components']['schemas'] = {**swagger['components']['schemas'], **schemas}
swagger['info']['version'] = mdw_version

with open(os.path.join(SWAGGER_OUTPUT_DIR, "swagger_v3.json"), 'w') as jsonfile:
  json.dump(swagger, jsonfile, indent=2)

with open(os.path.join(SWAGGER_OUTPUT_DIR, "swagger_v3.yaml"), 'w') as yamlfile:
  yamlfile.write(yaml.dump(swagger, default_flow_style=False, allow_unicode=True))
