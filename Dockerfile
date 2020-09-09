FROM elixir:1.10
# Add required files to download and compile only the dependencies
RUN apt-get -qq update && apt-get -qq -y install curl libsodium-dev jq build-essential libgmp10 \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*
# Prepare working folder
RUN mkdir -p /home/aeternity/node 

# Download, and unzip latest aeternity release archive 
WORKDIR /home/aeternity/node

RUN mkdir -p ./local/rel/aeternity/data/mnesia
RUN curl -s https://api.github.com/repos/aeternity/aeternity/releases/latest | \
       jq '.assets[1].browser_download_url' | \
       xargs curl -L --output aeternity.tar.gz  && tar -C ./local/rel/aeternity -xf aeternity.tar.gz 

RUN cp -r ./local/rel/aeternity/lib local/

# Copy elixir files needed to build a project
RUN mkdir  ae_mdw/
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

# Fetch the application dependencies and build the application
RUN mix deps.get
RUN mix deps.compile
ENV NODEROOT=/home/aeternity/node/local
RUN mix compile

RUN chmod +x entrypoint.sh
ENTRYPOINT [ "./entrypoint.sh" ]