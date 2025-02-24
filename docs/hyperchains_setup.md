# AeMdw Hyperhain Setup Documentation

## Overview

AeMdw is a middleware that acts as a caching and reporting layer for the [æternity blockchain](https://github.com/aeternity/aeternity). It responds to queries more efficiently than the node and supports additional queries.

The middleware runs an Aeternity Node alongside it in the same Docker container and BEAM VM instance, so you don't need to run a standalone one. This node can be configured using the `aeternity.yaml` file or by passing environment variables, just like configuring the node directly.

## Step 1: Generating Configuration Files

To properly configure your middleware for Aeternity Hyperchains, start by generating the necessary configuration files from `init.hyperchains.ae`.

1. **Access the Hyperchains Initialization Tool**:
    - Visit [init.hyperchains.ae](https://init.hyperchains.ae/) in your web browser.

2. **Input Node Information and Generate the Configuration Files**:
    
    - Click on the 'Get Started' button.
    - Follow the on-screen instructions to enter details about your Hyperchain node and select a pinning chain.
    - Download the `init.yaml` file.
    - Follow the 'Next Steps' to generate additional configuration files:
        - `aeternity.yaml`
        - `${NAME}_accounts.json`
        - `${NAME}_contracts.json`

---

## Step 2: Running the Docker Container

Once you have the necessary configuration files, you can run the middleware using Docker:

```
docker run -it --rm \
  -p 3013:3013 \
  -p 4000:4000 \
  -e AETERNITY_CONFIG=/home/aeternity/aeternity.yaml \
  -v ${PWD}/${NAME}/nodeConfig/aeternity.yaml:/home/aeternity/aeternity.yaml \
  -v ${PWD}/${NAME}/nodeConfig/${NAME}_accounts.json:/home/aeternity/node/local/rel/aeternity/data/aecore/${NAME}_accounts.json \
  -v ${PWD}/${NAME}/nodeConfig/${NAME}_contracts.json:/home/aeternity/node/local/rel/aeternity/data/aecore/${NAME}_contracts.json \
  aeternity/ae_mdw
```

- **Make sure you have enough account balance on the pinning chain for all of the accounts**
- The command assumes the configuration files are in the `${NAME}/nodeConfig` directory in your current working directory, where `${NAME}` is the name of your Hyperchain.
- This command uses the [middleware image](https://hub.docker.com/r/aeternity/ae_mdw), which differs from the [node image](https://hub.docker.com/r/aeternity/aeternity).

---

## Step 3: Persisting Node and Middleware Databases (Optional but Recommended)

To ensure data persistence across container restarts:

3. **Create the Data Directory** (if it doesn’t already exist):
    
    - In your working directory, create a `data` folder to store the node and middleware databases:
        
        ```
        mkdir -p ${PWD}/data
        ```
        
4. **Run the Docker Container with Volumes**:
    

```
docker run -it --rm \
  -p 3013:3013 \
  -p 4000:4000 \
  -e AETERNITY_CONFIG=/home/aeternity/aeternity.yaml \
  -v ${PWD}/${NAME}/nodeConfig/aeternity.yaml:/home/aeternity/aeternity.yaml \
  -v ${PWD}/${NAME}/nodeConfig/${NAME}_accounts.json:/home/aeternity/node/local/rel/aeternity/data/mnesia/${NAME}_accounts.json \
  -v ${PWD}/${NAME}/nodeConfig/${NAME}_contracts.json:/home/aeternity/node/local/rel/aeternity/data/mnesia/${NAME}_contracts.json \
  -v ${PWD}/data/mnesia:/home/aeternity/node/local/rel/aeternity/data/mnesia \
  -v ${PWD}/data/mdw.db:/home/aeternity/node/local/rel/aeternity/data/mdw.db \
  aeternity/ae_mdw
```

- `-v ${PWD}/data/mnesia:/home/aeternity/node/local/rel/aeternity/data/mnesia`: Persists the node database.
- `-v ${PWD}/data/mdw.db:/home/aeternity/node/local/rel/aeternity/data/mdw.db`: Persists the middleware database.

With this setup, the middleware will retain its state even after the container is stopped or restarted.

---

## Node Configuration Options

You can use the same configuration options available for the Aeternity node to further customize your setup. For more information on available options and how to modify the `aeternity.yaml` file, refer to the [Aeternity node documentation](https://github.com/aeternity/aeternity).
