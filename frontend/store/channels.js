import axios from 'axios'

export const state = () => ({
  channels: []
})

export const mutations = {
  setChannels (state, channels) {
    state.channels = channels
  }
}

export const actions = {
  getChannels: async function ({ rootState: { nodeUrl }, commit }) {
    try {
      const url = `${nodeUrl}/middleware/channels/active`
      const channels = await axios.get(url)
      console.info('MDW 🔗 ' + url)
      commit('setChannels', channels.data)
      return channels.data
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', { root: true })
    }
  },
  getChannelTx: async function ({ rootState: { nodeUrl }, commit }, channelId) {
    try {
      const url = `${nodeUrl}/middleware/channels/transactions/address/${channelId}`
      const channelTx = await axios.get(url)
      console.info('MDW 🔗 ' + url)
      return channelTx.data.transactions
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', { root: true })
    }
  }
}
