import axios from 'axios'

export const state = () => ({
  nodeStatus: {},
  nodeUrl: process.env.middlewareURL,
  wsUrl: process.env.middlewareWS,
  networkName: process.env.networkName,
  swaggerHub: process.env.swaggerHub,
  enableFaucet: process.env.enableFaucet,
  faucetApi: process.env.faucetAPI,
  error: '',
  height: 0,
  status: {},
  ws: null,
  wsConnected: false,
  filterOptions: [
    'All',
    'SpendTx',
    'OracleRegisterTx',
    'OracleExtendTx',
    'OracleQueryTx',
    'OracleResponseTx',
    'NamePreclaimTx',
    'NameClaimTx',
    'NameUpdateTx',
    'NameTransferTx',
    'NameRevokeTx',
    'GAAttachTx',
    'GAMetaTx',
    'ContractCallTx',
    'ContractCreateTx',
    'ChannelCreateTx',
    'ChannelDepositTx',
    'ChannelWithdrawTx',
    'ChannelCloseMutualTx',
    'ChannelForceProgressTx',
    'ChannelCloseSoloTx',
    'ChannelSlashTx',
    'ChannelSettleTx',
    'ChannelSnapshotSoloTx'
  ]
})

export const mutations = {
  /**
   * setNodeStatus
   * @param {Object} state
   * @param nodeStatus
   */
  setNodeStatus (state, nodeStatus) {
    Object.assign(state, { nodeStatus })
  },
  /**
   * changeNetwork
   * @param state
   * @param nodeUrl
   */
  changeNetworkUrl (state, nodeUrl) {
    state.nodeUrl = nodeUrl
  },
  /**
   * catchError
   * @param state
   * @param error
   */
  catchError (state, error) {
    state.error = error
  },
  /**
   * clearError
   * @param state
   */
  clearError (state) {
    state.error = ''
  },
  /**
   * setHeight mutates the
   * state property height
   * @param {Object} state
   * @param {Number} height
   */
  setHeight (state, height) {
    Object.assign(state, { height })
  },
  setStatus (state, status) {
    state.status = status
  },
  createWsClient (state) {
    state.ws = new WebSocket(state.wsUrl)
  },
  setWsConnectionStatus (state, status) {
    state.wsConnected = status
  }
}

export const actions = {
  async height ({ rootState: { nodeUrl }, commit }) {
    try {
      const url = `${nodeUrl}/v2/key-blocks/current/height`
      const { height } = (await axios.get(url)).data
      console.info('MDW 🔗 ' + url)
      commit('setHeight', height)
      return height
    } catch (e) {
      commit('catchError', 'Error', { root: true })
    }
  },
  async status ({ rootState: { nodeUrl }, commit }) {
    try {
      const url = `${nodeUrl}/v2/status`
      const status = (await axios.get(url)).data
      console.info('MDW 🔗 ' + url)
      commit('setStatus', status)
      return status
    } catch (e) {
      commit('catchError', 'Error', { root: true })
    }
  },
  setupWebSocket ({ state, commit, dispatch }) {
    if (process.client && !state.wsConnected) {
      commit('createWsClient')
      state.ws.onopen = () => {
        handleWsOpen(state.ws, commit, dispatch)
      }
      state.ws.onerror = e => {
        commit('catchError', e)
        commit('setWsConnectionStatus', false)
        handleWsOpen(state.ws, commit, dispatch)
      }
      state.ws.onclose = e => {
        commit('setWsConnectionStatus', false)
        handleWsOpen(state.ws, commit, dispatch)
      }
    }
  },
  async nuxtServerInit ({ dispatch }, { context }) {
    await dispatch('height')
    await Promise.all([
      dispatch('generations/nuxtServerInit', context),
      dispatch('transactions/nuxtServerInit', context)
    ])
  }
}

function handleWsOpen (socket, commit, dispatch) {
  commit('setWsConnectionStatus', true)
  socket.send('{"op":"Subscribe", "payload": "KeyBlocks"}')
  socket.send('{"op":"Subscribe", "payload": "MicroBlocks"}')
  socket.send('{"op":"Subscribe", "payload": "Transactions"}')
  socket.onmessage = e => {
    processWsData(e.data, commit, dispatch)
  }
}

function processWsData (data, commit, dispatch) {
  if (data.includes('payload')) {
    data = JSON.parse(data).payload
    if (data.tx) {
      commit('transactions/setTransactions', [data])
      dispatch('generations/updateTx', data)
    } else if (data.beneficiary) {
      commit('generations/setGenerations', [data])
      if (state.height < data.height) {
        commit('setHeight', data.height, {
          root: true
        })
      }
    } else if (data.key_block_id) {
      dispatch('generations/updateMicroBlock', data)
    }
  }
}
