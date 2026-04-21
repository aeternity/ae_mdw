# AeMdw Docker Setup Documentation

## Overview

AeMdw is a middleware that acts as a caching and reporting layer for the [æternity blockchain](https://github.com/aeternity/aeternity). It responds to queries more efficiently than the node and supports additional queries.

The middleware runs an Aeternity Node alongside it in the same Docker container and BEAM VM instance. This node can be configured using the `aeternity.yaml` file or by passing environment variables, just like configuring the node directly.

## Quick Start with Docker Compose

### Step 1: Clone the Repository

```
git clone https://github.com/aeternity/ae_mdw && cd ae_mdw
```

### Step 2: Database Snapshot (Optional)

1. Download a full backup from [Aeternity Downloads](https://downloads.aeternity.io).
    
2. Create a `data` directory under the root repository directory and extract the backup using the following command:
    
    ```
    tar -xvzf path-to-backup.tar.gz -C data
    ```
    
    This will extract the `mnesia` and `mdw.db` folders to the `data` directory.
    

### Step 3: Start the Application

Run the following command to start the application on the mainnet:

```
docker compose up
```

To check if the application is running properly, visit the `/status` endpoint and ensure that `node_height` is higher than `600000`.

## Running with Docker (Without Compose)

### Step 1: Create Directories and Set Permissions

Create the necessary directories for data storage and logs:

```
mkdir -p data/mnesia data/mdw.db log
```

Ensure the directories have the correct permissions to allow the middleware to write to them:

```
chown -R 1000 data log
```

### Step 2: Use a Database Snapshot (Optional)

If you want to use a database snapshot:

1. Download a full backup from [Aeternity Downloads](https://downloads.aeternity.io).
    
2. Extract the backup to the `data` directory:
    
    ```
    tar -xvzf path-to-backup.tar.gz -C data
    ```
    
    This will place the `mnesia` and `mdw.db` folders under the `data` directory.
    

### Step 3: Run the Container

Start the container with the following command:

```
docker run -it --name ae_mdw \
  -p 4000:4000 \
  -p 4001:4001 \
  -p 3113:3113 \
  -p 3013:3013 \
  -p 3014:3014 \
  -v ${PWD}/data/mnesia:/home/aeternity/node/data/mnesia \
  -v ${PWD}/data/mdw.db:/home/aeternity/node/data/mdw.db \
  -v ${PWD}/log:/home/aeternity/ae_mdw/log \
  -v ${PWD}/docker/aeternity.yaml:/home/aeternity/.aeternity/aeternity/aeternity.yaml \
  aeternity/ae_mdw:latest
```

This command starts the middleware in a docker container. The middleware will be available at `http://localhost:4000`. Note that you can pass the -d flag to run the container in detached mode.

### Step 4: Check the Status

To check if the middleware is running properly, visit the `/status` endpoint and ensure that `node_height` is higher than `0`.

### Step 5: Managing the Container

To check the logs, run the following command:

```
docker logs ae_mdw
```

To check the status of the container, run the following command:

```
docker ps -a
```

To stop the container, run the following command:

```
docker stop ae_mdw
```

To restart the container, run the following command:

```
docker start ae_mdw
```

## Customizing Configuration

Edit the configuration file `docker/aeternity.yaml` to specify network settings:

- `ae_mainnet` for mainnet
    
- `ae_uat` for testnet
    
- A custom network name if running your own network or a hyperchain
    

You can also pass environment variables to configure the node, similar to standard Aeternity Node configuration.

Refer to [Aeternity Configuration Docs](https://docs.aeternity.io/en/stable/configuration/) for more details.

### Middleware Environment Variables

The following environment variables configure the middleware itself (not the underlying node):

| Variable | Default | Description |
|---|---|---|
| `PORT` | `4000` | HTTP API port |
| `WS_PORT` | `4001` | WebSocket port |
| `DISABLE_IPV6` | `false` | Set to `true` to bind on IPv4 only (`0.0.0.0` instead of `::`) |
| `LOG_LEVEL` | `debug` | Log verbosity: `debug`, `info`, `notice`, `warning`, `error`, `critical`, `alert`, `emergency`, `none` |
| `LOG_FILE_PATH` | `log/info.log` | Path for the log file |
| `ENABLE_JSON_LOG` | `false` | Set to `true` to emit logs in JSON format |
| `ENABLE_CONSOLE_LOG` | `false` | Set to `true` to also log to stdout |
| `WEALTH_RANK_SIZE` | `200` | Number of top accounts tracked for the wealth rank endpoint |
| `MAX_SUBS_PER_CONN` | `100000` | Maximum WebSocket subscriptions per connection. 100k covers monitoring 100k accounts on a single connection; ETS cost is ~15 MB at that size |
| `MAX_WS_CONNECTIONS` | `1000` | Total simultaneous WebSocket connections across all clients |
| `MAX_WS_CONNECTIONS_PER_IP` | `50` | Maximum simultaneous connections from a single IP. 50 accommodates services with many workers behind shared egress NAT |
| `MAX_TOTAL_WS_SUBS` | `2000000` | Global cap on active subscription rows. At ~150 bytes/row this is ~300 MB |
| `MAX_WS_CLIENT_BACKLOG` | `2000` | Pending-message queue depth above which a slow client's messages are dropped. At peak ~750 object messages/s this is ~2.7 s of buffer |
| `MAX_PING_LIMIT` | `1000` | Maximum number of subscription entries included in a Ping response sample. When the total exceeds this, the response includes `"has_more": true` and `"count": N`. There is no cursor — Ping is a liveness and count-verification tool, not an enumerator. At 1000 entries the JSON payload is ~60 KB |
| `WS_SUBS_FULL_LIST_REPLY` | `false` | Set to `true` to return the full subscription list on every subscribe/unsubscribe response (legacy behaviour; use `Ping` to retrieve the full list instead) |
| `ENABLE_TELEMETRY` | `false` | Set to `true` to enable StatsD telemetry reporting |
| `TELEMETRY_STATSD_HOST` | hostname | StatsD host (used when `ENABLE_TELEMETRY=true`) |
| `TELEMETRY_STATSD_PORT` | `8125` | StatsD port |
| `TELEMETRY_POLLER_PERIOD` | `10000` | VM metrics polling interval in milliseconds |

## Additional Resources

- [Aeternity Node Configuration](https://docs.aeternity.io/en/stable/configuration/)
- [Aeternity Hyperchain Configuration](hyperchains_setup.md)
