# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20220801-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.13.4-erlang-23.3.4.17-debian-bullseye-20210902-slim
#
ARG ELIXIR_VERSION=1.13.4
ARG OTP_VERSION=23.3.4.18
ARG DEBIAN_VERSION=bullseye-20220801-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git sed curl libncurses5 libsodium-dev jq libgmp10 python3 python3-yaml \
    && ldconfig \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Prepare working folder
RUN mkdir -p /home/aeternity/node
COPY ./docker/aeternity.yaml /home/aeternity/aeternity.yaml

# Set build git revision
RUN mkdir /home/aeternity/node/ae_mdw
COPY .git .git
RUN BUILD_REV="$(git log -1 --format=%h)" && echo $BUILD_REV > /home/aeternity/node/ae_mdw/AEMDW_REVISION

WORKDIR /home/aeternity/node

# Download, and unzip latest aeternity release archive
ENV NODEROOT=/home/aeternity/node/local
ARG NODE_VERSION=6.8.1
ARG NODE_URL=https://github.com/aeternity/aeternity/releases/download/v${NODE_VERSION}/aeternity-v${NODE_VERSION}-ubuntu-x86_64.tar.gz
ENV NODEDIR=/home/aeternity/node/local/rel/aeternity
RUN mkdir -p ./local/rel/aeternity/data/mnesia
RUN curl -L --output aeternity.tar.gz ${NODE_URL} && tar -C ./local/rel/aeternity -xf aeternity.tar.gz

RUN chmod +x ${NODEDIR}/bin/aeternity
RUN cp -r ./local/rel/aeternity/lib local/
RUN sed -i 's/{max_skip_body_length, [0-9]\+}/{max_skip_body_length, 10240}/g' ${NODEDIR}/releases/${NODE_VERSION}/sys.config

# Check if the config file is OK
RUN ${NODEDIR}/bin/aeternity check_config /home/aeternity/aeternity.yaml

# prepare build dir
WORKDIR /home/aeternity/node/ae_mdw

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ARG MIX_ENV="prod"
ENV MIX_ENV=${MIX_ENV}

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY scripts scripts
COPY docs docs

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Generate swagger V2 file
RUN mix run --no-start -e 'IO.puts(Mix.Project.config[:version])' >AEMDW_VERSION
RUN scripts/swagger-docs.py >priv/static/swagger/swagger_v2.yaml

COPY rel rel
ENV RELEASE_NODE=aeternity@localhost
ENV RELEASE_DISTRIBUTION=name
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y git curl libstdc++6 openssl libncurses5 locales libncurses5 libsodium-dev libgmp10 \
  && ldconfig \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV NODEROOT=/home/aeternity/node/local
ENV NODEDIR=/home/aeternity/node/local/rel/aeternity

WORKDIR "/home/aeternity/node"

# set runner ENV
ARG MIX_ENV="prod"
ENV MIX_ENV=${MIX_ENV}
ENV AETERNITY_CONFIG=/home/aeternity/aeternity.yaml

# Only copy the final release from the build stage
COPY --from=builder /home/aeternity/node/ae_mdw/_build/${MIX_ENV}/rel/ae_mdw ./
COPY --from=builder /home/aeternity/node/local ./local
COPY ./docker/aeternity.yaml /home/aeternity/aeternity.yaml
COPY ./docker/healthcheck.sh /home/aeternity/healthcheck.sh
RUN chmod +x /home/aeternity/healthcheck.sh

# Create data directories in advance so that volumes can be mounted in there
# see https://github.com/moby/moby/issues/2259 for more about this nasty hack
RUN mkdir -p ./local/rel/aeternity/data/mnesia \
    && mkdir -p ./local/rel/aeternity/data/mdw.db

RUN useradd --uid 1000 --shell /bin/bash aeternity \
    && chown -R aeternity:aeternity /home/aeternity

ARG USER=aeternity
USER ${USER}

CMD ["/home/aeternity/node/bin/server"]
