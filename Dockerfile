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
ARG ELIXIR_VERSION=1.17.3
ARG OTP_VERSION=26.2.5.3
ARG NODE_VERSION=7.3.0-rc3
ARG DEBIAN_VERSION=bullseye-20240926-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG NODE_IMAGE=aeternity/aeternity:v${NODE_VERSION}
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${NODE_IMAGE} AS aeternity
FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git sed curl libncurses5 libsodium-dev jq libgmp10 python3 python3-yaml \
    && ldconfig \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Prepare working folder
RUN mkdir -p /home/aeternity/node
COPY ./docker/aeternity.yaml /home/aeternity/aeternity.yaml

# Set build git revision
RUN mkdir /home/aeternity/ae_mdw
COPY .git .git
RUN BUILD_REV="$(git log -1 --format=%h)" && echo $BUILD_REV > /home/aeternity/ae_mdw/AEMDW_REVISION

WORKDIR /home/aeternity/node

# Download, and unzip latest aeternity release archive
ARG DEV_MODE="false"
ENV DEV_MODE=${DEV_MODE}
ENV NODEROOT=/home/aeternity/node/

COPY --from=aeternity /home/aeternity/node ./
RUN chmod +x ${NODEROOT}/bin/aeternity
RUN sed -i 's/{max_skip_body_length, [0-9]\+}/{max_skip_body_length, 10240}/g' ${NODEROOT}/releases/*/sys.config

# Check if the config file is OK
RUN ${NODEROOT}/bin/aeternity check_config /home/aeternity/aeternity.yaml

# prepare build dir
WORKDIR /home/aeternity/ae_mdw

# This is necessary for QEMU build, otherwise it crashes when building for another platform: https://elixirforum.com/t/mix-deps-get-memory-explosion-when-doing-cross-platform-docker-build/57157
ENV ERL_FLAGS="+JMsingle true"

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

# Generate swagger V3 file
RUN cp /home/aeternity/node/lib/aehttp-*/priv/oas3.yaml docs/swagger_v3/node_oas3.yaml
RUN mix run --no-start -e 'IO.puts(Mix.Project.config[:version])' >AEMDW_VERSION
ARG PATH_PREFIX
RUN scripts/swagger-docs.py

# Install devmode
COPY docker/aeplugin_dev_mode aeplugin_dev_mode
RUN ./scripts/install-devmode.sh

# Copy release
COPY rel rel
ENV RELEASE_NODE=aeternity@localhost
ENV RELEASE_DISTRIBUTION=name
RUN mix phx.digest
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y git curl libstdc++6 openssl libncurses5 locales libncurses5 libsodium-dev libgmp10 libsnappy-dev libgflags2.2 \
  && ldconfig \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV NODEROOT=/home/aeternity/node/

# set runner ENV
ARG MIX_ENV="prod"
ENV MIX_ENV=${MIX_ENV}
ENV AETERNITY_CONFIG=/home/aeternity/.aeternity/aeternity/aeternity.yaml

# Only copy the final release from the build stage
WORKDIR "/home/aeternity/node"
COPY --from=builder /home/aeternity/node/ ./

WORKDIR "/home/aeternity/ae_mdw"
COPY --from=builder /home/aeternity/ae_mdw/_build/${MIX_ENV}/rel/ae_mdw ./

COPY ./docker/aeternity.yaml /home/aeternity/.aeternity/aeternity/aeternity.yaml
COPY ./docker/aeternity-dev.yaml /home/aeternity/.aeternity/aeternity/aeternity-dev.yaml
COPY ./docker/healthcheck.sh /home/aeternity/healthcheck.sh

COPY --from=aeternity /usr/local/lib/librocksdb.so.7.10.2 /usr/local/lib/

RUN ln -fs librocksdb.so.7.10.2 /usr/local/lib/librocksdb.so.7.10 \
    && ln -fs librocksdb.so.7.10.2 /usr/local/lib/librocksdb.so.7 \
    && ln -fs librocksdb.so.7.10.2 /usr/local/lib/librocksdb.so \
    && ldconfig
RUN chmod +x /home/aeternity/healthcheck.sh

# Create data directories in advance so that volumes can be mounted in there
# see https://github.com/moby/moby/issues/2259 for more about this nasty hack
RUN mkdir -p /home/aeternity/node/data/mnesia \
    && mkdir -p /home/aeternity/node/data/mdw.db

RUN useradd --uid 1000 --shell /bin/bash aeternity \
    && chown -R aeternity:aeternity /home/aeternity

ARG USER=aeternity
USER ${USER}

# Clear old logs
RUN rm -rf /home/aeternity/ae_mdw/log
RUN mkdir -p /home/aeternity/ae_mdw/log

HEALTHCHECK --start-period=10s --start-interval=2s --timeout=2s CMD /home/aeternity/healthcheck.sh
CMD ["/home/aeternity/ae_mdw/bin/server"]
