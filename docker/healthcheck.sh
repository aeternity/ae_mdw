#!/bin/bash
HTTP_RES=$(curl -s -o /dev/null -f localhost:4000/status && echo $?)
SWAGGER_RES=$(curl -s -o /dev/null -f localhost:4000/swagger/swagger_v2.yaml && echo $?)
DEPRECATED_SWAGGER_RES=$(curl -s -o /dev/null -f localhost:4000/v2/api && echo $?)
WS_RES=$(curl -i -H "Connection: close" -H "Upgrade: websocket" -f localhost:4001/websocket --stderr - | grep -q 426 && echo $?)
WS2_RES=$(curl -i -H "Connection: close" -H "Upgrade: websocket" -f localhost:4001/v2/websocket --stderr - | grep -q 426 && echo $?)

if [ "$HTTP_RES" == "0" ] && [ "$WS_RES" == "0" ] && [ "$WS2_RES" == "0" ] && \
   [ "$SWAGGER_RES" == "0" ] && [ "$DEPRECATED_SWAGGER_RES" ]; then
    exit 0
else
    exit 1
fi
