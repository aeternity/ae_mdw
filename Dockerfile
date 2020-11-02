FROM elixir:1.10
# Add required files to download and compile only the dependencies

# Install v10 Nodejs (compatible with the frontend)
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -

# Install other required dependencies
RUN apt-get -qq update && apt-get -qq -y install curl nodejs libncurses5 libsodium-dev jq build-essential gcc g++ make libgmp10 \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*
# Prepare working folder
RUN mkdir -p /home/aeternity/node
COPY ./docker/aeternity.yaml /home/aeternity/aeternity.yaml

WORKDIR /home/aeternity/node

# Download, and unzip latest aeternity release archive
ENV NODEDIR=/home/aeternity/node/local/rel/aeternity
RUN mkdir -p ./local/rel/aeternity/data/mnesia
RUN curl -s https://api.github.com/repos/aeternity/aeternity/releases/latest | \
       jq '.assets[1].browser_download_url' | \
       xargs curl -L --output aeternity.tar.gz  && tar -C ./local/rel/aeternity -xf aeternity.tar.gz 

RUN chmod +x ${NODEDIR}/bin/aeternity
RUN cp -r ./local/rel/aeternity/lib local/

# Copy all files, needed to build the project
RUN mkdir  ae_mdw/
COPY config ./ae_mdw/config
COPY lib ./ae_mdw/lib
COPY frontend/ ./ae_mdw/frontend
COPY mix.exs ae_mdw
COPY mix.lock ae_mdw
COPY Makefile ae_mdw
COPY docker/entrypoint.sh ae_mdw/entrypoint.sh

# Start building the mdw
WORKDIR /home/aeternity/node/ae_mdw
RUN  mix local.hex --force && mix local.rebar --force

# Fetch the application dependencies and build it
RUN mix deps.get
RUN mix deps.compile
ENV NODEROOT=/home/aeternity/node/local

# Check if the config file is OK
RUN ${NODEDIR}/bin/aeternity check_config /home/aeternity/aeternity.yaml
RUN make compile

RUN chmod +x entrypoint.sh
ENTRYPOINT [ "./entrypoint.sh" ]