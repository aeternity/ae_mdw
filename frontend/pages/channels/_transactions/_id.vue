<template>
  <div class="app-transactions">
    <PageHeader
      title="Channel Transactions"
      :has-crumbs="true"
      :page="{to: '/channels', name: 'Channels'}"
      :subpage="{to: `/channels/transactions/${$route.params.id}`, name: 'Channel Transactions'}"
    />
    <div
      v-if="!loading && transactions.length > 0"
    >
      <TxList>
        <TXListItem
          v-for="tx of transactions"
          :key="tx.hash"
          :data="tx"
        />
      </TxList>
    </div>
    <div v-if="loading">
      Loading....
    </div>
    <div v-if="!loading && transactions.length == 0">
      Channel not found.
      Please check the channel address and try again.
    </div>
  </div>
</template>

<script>

import TxList from '../../../partials/transactions/txList'
import TXListItem from '../../../partials/transactions/txListItem'
import PageHeader from '../../../components/PageHeader'

export default {
  name: 'ChannelTransactions',
  components: {
    TxList,
    TXListItem,
    PageHeader
  },
  data () {
    return {
      transactions: [],
      loading: true
    }
  },
  async asyncData ({ store, params }) {
    const transactions = await store.dispatch('channels/getChannelTx', params.id)
    return { transactions, loading: false }
  }
}
</script>
