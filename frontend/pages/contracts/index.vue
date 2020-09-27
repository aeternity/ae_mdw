<template>
  <div class="app-contracts">
    <PageHeader
      title="Contracts"
      :has-crumbs="true"
      :page="{to: '/contracts', name: 'Contracts'}"
    />
    <div v-if="Object.values(contracts).length">
      <ContractList>
        <Contract
          v-for="(item, index) in Object.values(contracts)"
          :key="index"
          :data="item"
        />
      </ContractList>
      <LoadMoreButton @update="loadMore" />
    </div>
    <div v-if="loading">
      Loading....
    </div>
    <div v-if="!loading && Object.values(contracts).length == 0">
      Nothing to see here right now....
    </div>
  </div>
</template>

<script>

import ContractList from '../../partials/contractList'
import Contract from '../../partials/contract'
import PageHeader from '../../components/PageHeader'
import LoadMoreButton from '../../components/loadMoreButton'
import { mapState } from 'vuex'

export default {
  name: 'AppContracts',
  components: {
    ContractList,
    Contract,
    PageHeader,
    LoadMoreButton
  },
  data () {
    return {
      page: 1,
      loading: true
    }
  },
  computed: {
    ...mapState('contracts', [
      'contracts'
    ])
  },
  async mounted () {
    this.loading = true
    await this.loadMore()
    this.loading = false
  },
  methods: {
    async loadMore () {
      await this.$store.dispatch('contracts/getContracts', { 'page': this.page, 'limit': 10 })
      this.page += 1
    }
  }
}
</script>
