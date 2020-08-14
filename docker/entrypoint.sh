#!/bin/bash
# Docker entrypoint script.

exec iex --sname aeternity@localhost -S mix phx.server 