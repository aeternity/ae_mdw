import Vue from 'vue'
import axios from 'axios'

export const state = () => ({
  contracts: []
})

export const mutations = {
  setContracts (state, contracts) {
    for (let contract of contracts) {
      Vue.set(state.contracts, contract.contract_id, contract)
    }
  }
}

export const actions = {
  getContracts: async function ({ rootState: { nodeUrl }, commit }, { page, limit }) {
    try {
      const url = `${nodeUrl}/middleware/contracts/all?limit=${limit}&page=${page}`
      const contracts = await axios.get(url)
      console.info('MDW 🔗 ' + url)
      commit('setContracts', contracts.data)
      return contracts.data
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', { root: true })
      return []
    }
  },

  getContractTx: async function ({ rootState: { nodeUrl }, commit }, { contract, page, limit }) {
    try {
      const url = `${nodeUrl}/middleware/contracts/transactions/address/${contract}?limit=${limit}&page=${page}`
      const contractTx = await axios.get(url)
      console.info('MDW 🔗 ' + url)
      return contractTx.data.transactions
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', { root: true })
      return { transactions: [] }
    }
  },
  getContractCalls: async function ({ rootState: { nodeUrl }, commit }, { contract, page, limit }) {
    try {
      const url = `${nodeUrl}/middleware/contracts/calls/address/${contract}?limit=${limit}&page=${page}`
      const contractCalls = await axios.get(url)
      console.info('MDW 🔗 ' + url)
      return contractCalls.data
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', { root: true })
      return []
    }
  }
}
