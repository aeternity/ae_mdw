<template>
  <div class="app-transaction">
    <PageHeader
      title="Transactions"
      :has-crumbs="true"
      :page="{to: '/transactions', name: 'Transactions'}"
      :subpage="{to: `/transactions/${$route.params.transaction}`, name: 'Transaction Overview'}"
    />
    <TransactionDetails
      :status="loading"
      :data="transaction"
    />
    <GenerationDetails
      v-if="generation && height"
      :data="generation"
      :dynamic-data="height"
      :status="loading"
    />
  </div>
</template>

<script>
import GenerationDetails from '../../../partials/generationDetails'
import TransactionDetails from '../../../partials/transactionDetails'
import PageHeader from '../../../components/PageHeader'
import { transformMetaTx } from '../../../store/utils'

export default {
  name: 'AppTransaction',
  components: {
    GenerationDetails,
    TransactionDetails,
    PageHeader
  },
  data () {
    return {
      transation: {},
      generation: {},
      height: 0,
      loading: true
    }
  },
  async asyncData ({ store, params: { transaction }, error }) {
    let txDetails = null
    let generation = null
    let height = null
    if (store.transactions) {
      txDetails = store.transactions.transactions[txDetails]
    }
    if (!txDetails) {
      txDetails = await store.dispatch('transactions/getTransactionByHash', transaction)
    }
    if (!txDetails) {
      return error({
        message: `Transaction not found`,
        statusCode: 400
      })
    }
    if (txDetails.tx.type === 'GAMetaTx') {
      txDetails = transformMetaTx(txDetails)
    }
    if (store.generations) {
      generation = store.generations.generations[txDetails.block_height]
    }
    if (!generation) {
      generation = (await store.dispatch('generations/getGenerationByRange', { start: (txDetails.block_height - 1), end: (txDetails.block_height + 1) }))[txDetails.block_height]
    }
    if (!store.height) {
      height = await store.dispatch('height')
    }
    return { transaction: txDetails, generation, height, loading: false }
  }
}
</script>
