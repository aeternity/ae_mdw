#!/bin/bash

set -xe

mix format --check-formatted
mix credo diff master
