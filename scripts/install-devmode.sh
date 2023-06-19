#!/bin/bash

set -xe

if [ "$DEV_MODE" = "true" ]; then
  echo "Installing dev mode.."
  mkdir src
  cp -r aeplugin_dev_mode/src src/aeplugin_dev_mode
  cp -r aeplugin_dev_mode/include include/
else
  echo "Not installing devmode"
fi
