#!/bin/bash
HTTP_RES=$(curl -s -o /dev/null -f localhost:4000/status && echo $?)
SWAGGER_RES=$(curl -s -o /dev/null -f localhost:4000/swagger/swagger_v2.json && echo $?)
DEPRECATED_SWAGGER_RES=$(curl -s -o /dev/null -f localhost:4000/v2/api && echo $?)

ws_check() {
  curl -sS -m 0.5 -i \
    -H "Connection: Upgrade" -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" -H "Sec-WebSocket-Version: 13" \
    "http://localhost:4001$1" 2>&1 | grep -q " 101 " && echo 0 || echo 1
}
WS_RES=$(ws_check /websocket)
WS2_RES=$(ws_check /v2/websocket)

if [ "$HTTP_RES" == "0" ] && [ "$WS_RES" == "0" ] && [ "$WS2_RES" == "0" ] && \
   [ "$SWAGGER_RES" == "0" ] && [ "$DEPRECATED_SWAGGER_RES" == "0" ]; then
    exit 0
else
    exit 1
fi
