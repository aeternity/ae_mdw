<template>
  <div class="app-transactions">
    <PageHeader
      title="Account"
      :has-crumbs="true"
      :page="{to: `/account/transactions/${$route.params.id}`, name: `${account.id}(${amount})`}"
    />
    <div class="filter">
      <multiselect
        v-model="value"
        :options="options"
        :allow-empty="false"
        :loading="loading"
        placeholder="Select transaction type...."
        @input="processInput"
      />
    </div>
    <div v-if="transactions.length > 0 && !account.error">
      <TxList>
        <TXListItem
          v-for="(tx, index) of transactions"
          :key="index"
          :data="tx"
          :address="`${$route.params.id}`"
        />
      </TxList>
      <LoadMoreButton @update="loadMore" />
    </div>
    <div v-if="loading">
      Loading....
    </div>
    <div v-if="!loading && !account.error &&transactions.length == 0">
      No matching transactions found for the selected type.
    </div>
    <div v-if="!loading && account.error">
      {{ account.error }}
    </div>
  </div>
</template>

<script>

import TxList from '../../../partials/transactions/txList'
import TXListItem from '../../../partials/transactions/txListItem'
import PageHeader from '../../../components/PageHeader'
import LoadMoreButton from '../../../components/loadMoreButton'
import prefixAmount from '../../../plugins/filters/prefixedAmount'
import Multiselect from 'vue-multiselect'
import { transformMetaTx } from '../../../store/utils'

export default {
  name: 'AccountTransactions',
  components: {
    TxList,
    TXListItem,
    PageHeader,
    LoadMoreButton,
    Multiselect
  },
  data () {
    return {
      account: {
        balance: 0
      },
      transactions: [],
      page: 1,
      loading: true,
      value: 'All',
      options: this.$store.state.filterOptions
    }
  },
  computed: {
    amount () {
      return prefixAmount(this.account.balance)
    }
  },
  async asyncData ({ store, params, query }) {
    let value = null
    if (query.txtype) {
      if (store.state.filterOptions.indexOf(query.txtype) > 0) {
        value = query.txtype
      }
    }
    const tx = await store.dispatch('transactions/getTransactionByAccount', { account: params.id, page: 1, limit: 10, txtype: value })
    const account = await store.dispatch('account/getAccountDetails', params.id)
    const transactions = []
    tx.forEach(element => {
      element = element.tx.type === 'GAMetaTx' ? transformMetaTx(element) : element
      transactions.push(element)
    })
    value = value || 'All'
    return { address: params.id, transactions, page: 2, account, value, loading: false }
  },
  methods: {
    async loadMore () {
      const txtype = this.value === 'All' ? null : this.value
      const tx = await this.$store.dispatch('transactions/getTransactionByAccount', { account: this.account.id, page: this.page, limit: 10, txtype })
      tx.forEach(element => {
        element = element.tx.type === 'GAMetaTx' ? transformMetaTx(element) : element
        this.transactions.push(element)
      })
      this.page += 1
    },
    async processInput () {
      this.loading = true
      this.page = 1
      this.transactions = []
      await this.loadMore()
      this.loading = false
    }
  }
}
</script>
