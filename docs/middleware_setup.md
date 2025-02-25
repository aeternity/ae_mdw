# AeMdw Docker Setup Documentation

## Overview

AeMdw is a middleware that acts as a caching and reporting layer for the [Ã¦ternity blockchain](https://github.com/aeternity/aeternity). It responds to queries more efficiently than the node and supports additional queries.

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
docker run -it --rm \
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

## Customizing Configuration

Edit the configuration file `docker/aeternity.yaml` to specify network settings:

- `ae_mainnet` for mainnet
    
- `ae_uat` for testnet
    
- A custom network name if running your own network or a hyperchain
    

You can also pass environment variables to configure the node, similar to standard Aeternity Node configuration.

Refer to [Aeternity Configuration Docs](https://docs.aeternity.io/en/stable/configuration/) for more details.

## Additional Resources

- [Aeternity Node Configuration](https://docs.aeternity.io/en/stable/configuration/)
- [Aeternity Hyperchain Configuration](hyperchains_setup.md)
