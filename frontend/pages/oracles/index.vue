<template>
  <div class="app-oracles">
    <PageHeader
      title="Oracles"
      :has-crumbs="true"
      :page="{to: '/oracles', name: 'Oracles'}"
    />
    <div v-if="Object.keys(oracles).length">
      <OracleList>
        <Oracle
          v-for="(item, index) of Object.values(oracles)"
          :key="index"
          :data="item"
        />
      </OracleList>
      <LoadMoreButton @update="loadMore" />
    </div>
    <div v-if="loading">
      Loading....
    </div>
    <div v-if="!loading && Object.values(oracles).length == 0">
      Nothing to see here right now....
    </div>
  </div>
</template>

<script>
import OracleList from '../../partials/oracles/oracleList'
import Oracle from '../../partials/oracles/oracle'
import PageHeader from '../../components/PageHeader'
import LoadMoreButton from '../../components/loadMoreButton'
import { mapState } from 'vuex'

export default {
  name: 'AppOracles',
  components: {
    OracleList,
    Oracle,
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
    ...mapState('oracles', [
      'oracles'
    ])
  },
  async mounted () {
    this.loading = true
    await this.loadMore()
    this.loading = false
  },
  methods: {
    async loadMore () {
      await this.$store.dispatch('oracles/getOracles', { 'page': this.page, 'limit': 10 })
      this.page += 1
    }
  }
}
</script>
