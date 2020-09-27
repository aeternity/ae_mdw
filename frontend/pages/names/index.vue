<template>
  <div class="app-names">
    <PageHeader
      title="Names"
      :has-crumbs="true"
      :page="{to: '/names', name: 'Names'}"
    />
    <div v-if="!loading && names.length > 0">
      <NameList>
        <Name
          v-for="(item, index) of names"
          :key="index"
          :data="item"
        />
      </NameList>
      <LoadMoreButton @update="loadMore" />
    </div>
    <div v-if="loading">
      Loading....
    </div>
    <div v-if="!loading && names.length == 0">
      Nothing to see here right now....
    </div>
  </div>
</template>

<script>
import NameList from '../../partials/names/nameList'
import Name from '../../partials/names/name'
import PageHeader from '../../components/PageHeader'
import LoadMoreButton from '../../components/loadMoreButton'
import { mapState } from 'vuex'

export default {
  name: 'AppNames',
  components: {
    NameList,
    Name,
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
    ...mapState('names', [
      'names'
    ])
  },
  async mounted () {
    this.loading = true
    await this.loadMore()
    this.loading = false
  },
  methods: {
    async loadMore () {
      await this.$store.dispatch('names/getNames', { 'page': this.page, 'limit': 10 })
      this.page += 1
    }
  }
}
</script>
