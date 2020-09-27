<template>
  <div class="app-transactions">
    <PageHeader
      title="Transactions"
      :has-crumbs="true"
      :page="{to: '/transactions', name: 'Transactions'}"
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
    <div v-if="Object.keys(transactions).length > 0">
      <TxList>
        <TXListItem
          v-for="(item, index) in Object.values(transactions)"
          :key="index"
          :data="item"
        />
      </TxList>
      <LoadMoreButton @update="loadmore" />
    </div>
    <div v-if="loading">
      Loading....
    </div>
    <div v-if="!loading && Object.keys(transactions).length == 0">
      No matching transactions found for the selected type.
    </div>
  </div>
</template>

<script>
import TxList from '../../partials/transactions/txList'
import TXListItem from '../../partials/transactions/txListItem'
import PageHeader from '../../components/PageHeader'
import LoadMoreButton from '../../components/loadMoreButton'
import Multiselect from 'vue-multiselect'
import { transformMetaTx } from '../../store/utils'

export default {
  name: 'AppTransactions',
  components: {
    TxList,
    TXListItem,
    PageHeader,
    LoadMoreButton,
    Multiselect
  },
  data () {
    return {
      typePage: 1,
      loading: true,
      value: 'All',
      transactions: {},
      options: this.$store.state.filterOptions
    }
  },
  async mounted () {
    if (this.$route.query.txtype && this.options.indexOf(this.$route.query.txtype) > 0) {
      this.value = this.$route.query.txtype
      await this.getTxByType()
    } else {
      if (!Object.keys(this.$store.state.transactions.transactions).length) {
        await this.$store.dispatch('height')
        await this.getAllTx()
      } else {
        this.transactions = this.$store.state.transactions.transactions
      }
    }
    this.loading = false
  },
  methods: {
    async loadmore () {
      if (this.value === 'All') {
        await this.getAllTx()
      } else {
        await this.getTxByType()
      }
      this.$route.query.txtype = this.value
    },
    async getAllTx () {
      const tx = await this.$store.dispatch(
        'transactions/getLatestTransactions',
        { limit: 10 }
      )
      tx.forEach(element => {
        element = element.tx.type === 'GAMetaTx' ? transformMetaTx(element) : element
        this.transactions = { ...this.transactions, [element.hash]: element }
      })
    },
    async getTxByType () {
      const tx = await this.$store.dispatch('transactions/getTxByType', {
        page: this.typePage,
        limit: 10,
        txtype: this.value
      })
      tx.forEach(element => {
        element = element.tx.type === 'GAMetaTx' ? transformMetaTx(element) : element
        this.transactions = { ...this.transactions, [element.hash]: element }
      })
      this.typePage += 1
    },
    async processInput () {
      if (this.value === 'All') {
        this.tranasction = {}
        this.transactions = this.$store.state.transactions.transactions
      } else {
        this.loading = true
        this.typePage = 1
        this.transactions = {}
        await this.loadmore()
        this.loading = false
      }
    }
  }
}
</script>
