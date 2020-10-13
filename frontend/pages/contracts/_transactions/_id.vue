<template>
  <div class="app-transactions">
    <PageHeader
      title="Contracts Transactions"
      :has-crumbs="true"
      :page="{to: '/Contracts', name: 'Contracts'}"
      :subpage="{to: `/contracts/transactions/${$route.params.id}`, name: 'Contract Transactions'}"
    />
    <div
      v-if="!loading && transactions.length > 0"
    >
      <TransactionDetails
        v-for="tx of transactions"
        :key="tx.hash"
        :data="tx"
      />
      <LoadMoreButton @update="loadMore" />
    </div>
    <div v-if="loading">
      Loading....
    </div>
    <div v-if="!loading && transactions.length == 0">
      Contract not found.
      Please check the contract address and try again.
    </div>
  </div>
</template>

<script>

import PageHeader from '../../../components/PageHeader'
import TransactionDetails from '../../../partials/transactionDetails'
import LoadMoreButton from '../../../components/loadMoreButton'

export default {
  name: 'ChannelTransactions',
  components: {
    TransactionDetails,
    LoadMoreButton,
    PageHeader
  },
  data () {
    return {
      contract: '',
      transactions: [],
      loading: true,
      page: 1
    }
  },
  async asyncData ({ store, params }) {
    let transactions = await store.dispatch('contracts/getContractTx', { contract: params.id, page: 1, limit: 10 })
    const calls = await store.dispatch('contracts/getContractCalls', { contract: params.id, page: 1, limit: 10 })
    for (const tx of transactions) {
      const call = calls.find(x => x.transaction_id === tx.hash)
      if (call) {
        tx.arguments = call.arguments
        tx.callinfo = call.callinfo
        if (call.result) {
          tx.result = call.result
        }
      }
    }
    return { contract: params.id, transactions, loading: false, page: 2 }
  },
  methods: {
    async loadMore () {
      let transactions = await this.$store.dispatch('contracts/getContractTx', { contract: this.contract, page: this.page, limit: 10 })
      const calls = await this.$store.dispatch('contracts/getContractCalls', { contract: this.contract, page: this.page, limit: 10 })
      for (const tx of transactions) {
        const call = calls.find(x => x.transaction_id === tx.hash)
        if (call) {
          tx.arguments = call.arguments
          tx.callinfo = call.callinfo
          if (call.result) {
            tx.result = call.result
          }
        }
      }
      this.transactions = [...this.transactions, ...transactions]
      this.page += 1
    }
  }
}
</script>
