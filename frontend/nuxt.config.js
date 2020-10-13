const pkg = require('./package')
const path = require("path")
module.exports = {
  mode: process.env.NUXT_APP_MODE || 'spa',

  target: 'static',

  /*
  ** Headers of the page
  */
 generate: {dir: path.resolve(__dirname, "../priv/static/frontend")},
  head: {
    title: 'æternal',
    meta: [
      { charset: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { hid: 'description', name: 'description', content: pkg.description }
    ],
    link: [
      { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' }
    ]
  },

  /*
  ** Customize the progress-bar color
  */
  loading: {
    continuous: true,
    color: '#FF0D6A'
  },

  /*
  ** Global CSS
  */
  css: [
    { src: 'styles/index.scss', lang: 'scss' },
    {
      src: 'vue-multiselect/dist/vue-multiselect.min.css',
      lang: 'css'
    }
  ],
  env: {
    baseUrl: process.env.BASE_URL || 'http://localhost:4000', // Phoenix server url  
    middlewareURL: process.env.NUXT_APP_NODE_URL || 'https://mainnet.aeternal.io',
    middlewareWS: process.env.NUXT_APP_NODE_WS || 'wss://mainnet.aeternal.io/websocket',
    networkName: process.env.NUXT_APP_NETWORK_NAME || 'MAINNET',
    swaggerHub: process.env.NUXT_APP_SWAGGER_HUB || 'http://localhost:4000/swagger',
    enableFaucet: process.env.NUXT_APP_ENABLE_FAUCET || false,
    faucetAPI: process.env.NUXT_APP_FAUCET_API || 'https://testnet.faucet.aepps.com/account'
  },
  /*
  ** Plugins to load before mounting the App
  */
  plugins: [
    { src: '~/plugins/directives/copyToClipboard.js' },
    { src: '~/plugins/directives/removeSpacesOnCopy.js' },
    { src: '~/plugins/directives/vueSliderComponent.js', mode: 'client' }
  ],
  /*
    ** Router config
  */
  router: {
   base: "/frontend/",
    linkActiveClass: 'active-link',
    linkExactActiveClass: 'exact-active-link'
  },

  /*
  ** Nuxt.js modules
  */
  modules: [
    // Doc: https://github.com/nuxt-community/axios-module#usage
    '@nuxtjs/axios',
    '@nuxtjs/svg-sprite'
  ],
  /*
  ** Axios module configuration
  */
  axios: {
    // See https://github.com/nuxt-community/axios-module#options
  },

  /*
  ** Build configuration
  */
  build: {
    /*
    ** You can extend webpack config here
    */

    postcss: {
      plugins: {
        autoprefixer: {}
      }
    },
    extend (config, ctx) {
      // Run ESLint on save
      if (ctx.isDev && ctx.isClient) {
        config.module.rules.push({
          enforce: 'pre',
          test: /\.(js|vue)$/,
          loader: 'eslint-loader',
          exclude: /(node_modules)/
        })
      }

      // config.resolve.alias['~src'] = projectSrc
      // config.resolve.alias['~utils'] = path.join(projectSrc, 'utils')
    }
  }
}
