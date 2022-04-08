#!/bin/bash

URL_1="${1:-https://mainnet.aeternity.io/mdw/}"
URL_2="${2:-http://localhost:4000/}"

ERROR=0
SUCCESS=0

echo "Diffing $URL_1 and $URL_2 ..."

while read LINE; do
  if [[ $LINE =~ mdw\/(.*?)\" ]]; then
    ROUTE="${BASH_REMATCH[1]}"

    echo "Diffing '$ROUTE'"

    curl -so '.endpoint-diff.json1.tmp' "$URL_1$ROUTE"
    curl -so '.endpoint-diff.json2.tmp' "$URL_2$ROUTE"

    if diff .endpoint-diff.json1.tmp .endpoint-diff.json2.tmp; then
        ((SUCCESS=SUCCESS + 1))
    else
        ((ERROR=ERROR + 1))
    fi
  fi
done < README.md

rm -f .endpoint-diff.json1.tmp .endpoint-diff.json2.tmp

echo "success $SUCCESS"
echo "error $ERROR"
