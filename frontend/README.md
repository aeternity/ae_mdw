# Aeternal Frontend

## Getting started

1. Git clone the middleware repository
2. Navigate to `/frontend` folder
3. Install the dependencies: `npm install`
4. Run the application:

    - Dev Mode: `npm run dev`
    - Prod: `npm run build && npm start`

## Supported Environment Variables

- NUXT_APP_NODE_URL: Middleware url you want the frontend to connect to (default: `https://testnet.mdw.aepps.com`).
- NUXT_APP_NODE_WS: Middleware websocket url (default: `wss://testnet.mdw.aepps.com/websocket`).
- NUXT_APP_NETWORK_NAME: Network name to show in the network indicator (default: `TEST NET`).
- NUXT_APP_SWAGGER_HUB: SwaggerHub link to use (default: http://localhost:4000/swagger).
