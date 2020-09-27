import axios from 'axios'
export const state = () => ({
  names: []
})

export const mutations = {
  setNames (state, names) {
    state.names = [...state.names, ...names]
  }
}

export const actions = {
  getNames: async function ({ rootState: { nodeUrl }, commit }, { page, limit }) {
    try {
      const url = `${nodeUrl}/middleware/names?limit=${limit}&page=${page}`
      const names = await axios.get(url)
      console.info('MDW 🔗 ' + url)
      commit('setNames', names.data)
      return names.data
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', { root: true })
    }
  },
  searchNames: async function ({ rootState: { nodeUrl }, commit }, query) {
    try {
      const url = `${nodeUrl}/middleware/names/${query}`
      const names = await axios.get(url)
      console.info('MDW 🔗 ' + url)
      return names.data
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', { root: true })
    }
  },
  getActiveNameAuctions: async function ({ rootState: { nodeUrl }, commit }, { page, limit, sort, length }) {
    try {
      let url = `${nodeUrl}/middleware/names/auctions/active?limit=${limit}&page=${page}&sort=${sort}`
      if (length > 0) {
        url += `&length=${length}`
      }
      const auctions = await axios.get(url)
      console.info('MDW 🔗 ' + url)
      return auctions.data
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', { root: true })
      return []
    }
  }
}
