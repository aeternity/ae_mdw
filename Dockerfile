FROM hexpm/elixir:1.13.4-erlang-23.3.4.17-debian-buster-20220801
# Add required files to download and compile only the dependencies

# Install other required dependencies
RUN apt-get -qq update && apt-get -qq -y install git curl libncurses5 libsodium-dev jq build-essential gcc g++ make libgmp10 \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*

# Prepare working folder
RUN mkdir -p /home/aeternity/node
COPY ./docker/aeternity.yaml /home/aeternity/aeternity.yaml

# Set build git revision
RUN mkdir /home/aeternity/node/ae_mdw
COPY .git .git
RUN BUILD_REV="$(git log -1 --format=%h)" && echo $BUILD_REV > /home/aeternity/node/ae_mdw/AEMDW_REVISION
RUN rm -r .git

WORKDIR /home/aeternity/node

# Download, and unzip latest aeternity release archive
ARG NODE_VERSION=6.5.2
ENV NODEDIR=/home/aeternity/node/local/rel/aeternity
RUN mkdir -p ./local/rel/aeternity/data/mnesia
RUN curl -L --output aeternity.tar.gz https://github.com/aeternity/aeternity/releases/download/v${NODE_VERSION}/aeternity-v${NODE_VERSION}-ubuntu-x86_64.tar.gz && tar -C ./local/rel/aeternity -xf aeternity.tar.gz

RUN chmod +x ${NODEDIR}/bin/aeternity
RUN cp -r ./local/rel/aeternity/lib local/

# Check if the config file is OK
RUN ${NODEDIR}/bin/aeternity check_config /home/aeternity/aeternity.yaml

# Copy all files, needed to build the project
COPY config ./ae_mdw/config
COPY lib ./ae_mdw/lib
COPY priv ./ae_mdw/priv
COPY mix.exs ae_mdw
COPY mix.lock ae_mdw
COPY Makefile ae_mdw
COPY docker/entrypoint.sh ae_mdw/entrypoint.sh

# Start building the mdw
WORKDIR /home/aeternity/node/ae_mdw
RUN  mix local.hex --force && mix local.rebar --force

# Fetch the application dependencies and build it
ARG MIX_ENV
ENV MIX_ENV=${MIX_ENV}
RUN mix deps.get
RUN mix deps.compile
ENV NODEROOT=/home/aeternity/node/local
RUN mix compile
RUN mix phx.digest

RUN chmod +x entrypoint.sh
ENTRYPOINT [ "./entrypoint.sh" ]
