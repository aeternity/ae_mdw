#!/usr/bin/env python3

import yaml
import os
from glob import glob
from pathlib import Path

SWAGGER_DOCS_DIR = 'docs/swagger_v2/'

# Read YAML file
schemas = {}
paths = {}
base_yaml = None

with open(os.path.join(SWAGGER_DOCS_DIR, 'base.yaml')) as base_stream:
    base_yaml = yaml.safe_load(base_stream)

for filepath in Path(SWAGGER_DOCS_DIR).glob("*.spec.yaml"):
    with open(filepath, 'r') as stream:
        data_loaded = yaml.safe_load(stream)
        schemas = {**schemas, **data_loaded['schemas']}
        paths = {**paths, **data_loaded['paths']}

base_yaml['paths'] = paths
base_yaml['components']['schemas'] = {**base_yaml['components']['schemas'], **schemas}

# Output YAML
print(yaml.dump(base_yaml, default_flow_style=False, allow_unicode=True))
