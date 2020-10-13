FROM node:10.15.1-alpine as frontend-build
WORKDIR /app
RUN apk add make gcc g++ python git
COPY package*.json ./
RUN npm install
COPY . .
ARG NODE_URL
ARG NODE_WS
ARG NETWORK_NAME
ARG ENABLE_FAUCET
RUN NUXT_APP_ENABLE_FAUCET=$ENABLE_FAUCET NUXT_APP_NODE_URL=$NODE_URL NUXT_APP_NODE_WS=$NODE_WS NUXT_APP_NETWORK_NAME=$NETWORK_NAME npm run build


FROM node:10.16.3-stretch as frontend
WORKDIR /app
COPY --from=frontend-build /app/.nuxt /app/.nuxt
COPY --from=frontend-build /app/static /app/static
RUN npm install nuxt@2.9.2 @nuxtjs/axios@5.5.4 @download/blockies@1.0.3 clipboard-copy@3.0.0 vue-multiselect@2.1.6 bignumber.js@9.0.0 vue-slider-component@3.0.41 && \
    npm cache clean --force
COPY package.json package.json
COPY LICENSE.md LICENSE.md
ENV HOST 0.0.0.0
EXPOSE 80
CMD [ "npm", "start" ]