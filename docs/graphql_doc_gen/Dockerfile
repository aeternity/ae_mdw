FROM node:current-alpine
RUN npm install -g spectaql
WORKDIR /docs
COPY ./spectaql-config.yml .
EXPOSE 4400
CMD ["npx", "spectaql", "-d", "spectaql-config.yml"]
