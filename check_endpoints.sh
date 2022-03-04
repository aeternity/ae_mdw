#!/bin/bash

BASE_URL="https://mainnet.aeternity.io/mdw/"

ERROR=0
SUCCESS=0

while read LINE; do
  if [[ $LINE =~ mdw\/(.*?)\" ]]; then
    ROUTE="${BASH_REMATCH[1]}"

    STATUS=$(curl -so '.check_endpoints_tmp.json' -w '%{response_code}' "$BASE_URL$ROUTE")

    if [ "$STATUS" != "200" ]; then
        echo "error $STATUS $BASE_URL$ROUTE"
        cat .check_endpoints_tmp.json
        echo ""
        ((ERROR=ERROR + 1))
    else
        ((SUCCESS=SUCCESS + 1))
    fi
  fi
done < README.md

echo "success $SUCCESS"
echo "error $ERROR"