import Vue from 'vue'
import axios from 'axios'

export const state = () => ({
  generations: {},
  hashToHeight: {},
  lastFetchedGen: 0
})

export const mutations = {
  setGenerations (state, generations) {
    for (let i of Object.keys(generations)) {
      const generation = generations[i]
      if (!generation.micro_blocks) {
        generation.micro_blocks = {}
      }
      Vue.set(state.hashToHeight, generation.hash, generation.height)
      Vue.set(state.generations, generation.height, generation)
    }
  },
  setLastFetched (state, last) {
    state.lastFetchedGen = last
  },
  setMicroBlockGen (state, mb) {
    const height = state.hashToHeight[mb.prev_key_hash]
    if (!mb.transactions) {
      mb.transactions = {}
    }
    state.generations[height]['micro_blocks'][mb.hash] = mb
  },
  setTxGen (state, tx) {
    state.generations[tx.block_height]['micro_blocks'][tx.block_hash]['transactions'][tx.hash] = tx
  }
}

export const actions = {
  getLatestGenerations: async function ({ state, rootState: { height }, commit, dispatch }, maxBlocks) {
    try {
      const range = calculateBlocksToFetch(height, state.lastFetchedGen, maxBlocks)
      return await dispatch('getGenerationByRange', range)
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', { root: true })
    }
  },
  getGenerationByRange: async function ({ rootState: { nodeUrl }, commit }, { start, end }) {
    try {
      const url = `${nodeUrl}/middleware/generations/${start}/${end}`
      const generations = await axios.get(url)
      console.info('MDW 🔗 ' + url)
      commit('setGenerations', generations.data.data)
      commit('setLastFetched', start)
      return generations.data.data
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', { root: true })
    }
  },
  getGenerationByHash: async function ({ rootState: { nodeUrl }, commit, dispatch }, keyHash) {
    try {
      const url = `${nodeUrl}/v2/key-blocks/hash/${keyHash}`
      const generations = await axios.get(url)
      console.info('MDW 🔗 ' + url)
      commit('setGenerations', generations.data)
      await dispatch('getGenerationByRange', { start: generations.data.height, end: generations.data.height })
      return generations.data.data
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', {
        root: true
      })
    }
  },
  updateMicroBlock: async function ({ state, commit, dispatch }, mb) {
    try {
      if (!state.hashToHeight[mb.prev_key_hash]) {
        await dispatch('getGenerationByHash', mb.prev_key_hash)
      } else {
        commit('setMicroBlockGen', mb)
      }
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', {
        root: true
      })
    }
  },
  updateTx: async function ({ state, rootState: { nodeUrl }, commit, dispatch }, tx) {
    try {
      if (!state.generations[tx.block_height]) {
        await dispatch('getGenerationByRange', tx.block_height, tx.block_height)
      }
      if (!state.generations[tx.block_height]['micro_blocks'][tx.block_hash]) {
        const mb = await axios.get(nodeUrl + '/v2/micro-blocks/hash/' + tx.block_hash + '/header')
        commit('setMicroBlockGen', mb)
      }
      commit('setTxGen', tx)
    } catch (e) {
      console.log(e)
      commit('catchError', 'Error', {
        root: true
      })
    }
  },
  nuxtServerInit ({ dispatch }, context) {
    return (
      dispatch('getLatestGenerations', 10)
    )
  }
}

function calculateBlocksToFetch (height, lastFetchedGen, maxBlocks) {
  let start = 0
  let end = 0
  if (!lastFetchedGen) {
    start = height - maxBlocks
    end = height
  } else {
    start = lastFetchedGen - maxBlocks - 1
    end = lastFetchedGen - 1
  }
  return { start, end }
}
