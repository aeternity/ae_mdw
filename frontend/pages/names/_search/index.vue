<template>
  <div class="app-names">
    <PageHeader
      title="Names"
      :has-crumbs="true"
      :page="{to: `/names/search/${$route.params.search}`, name: `Search results for ${$route.params.search}`}"
    />
    <div v-if="!loading && names.length > 0">
      <NameList>
        <Name
          v-for="(item, index) of names"
          :key="index"
          :data="item"
        />
      </NameList>
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
import NameList from '../../../partials/names/nameList'
import Name from '../../../partials/names/name'
import PageHeader from '../../../components/PageHeader'

export default {
  name: 'AppNames',
  components: {
    NameList,
    Name,
    PageHeader
  },
  data () {
    return {
      names: [],
      loading: true
    }
  },
  async asyncData ({ store, params }) {
    const names = await store.dispatch('names/searchNames', params.search)
    return { names, loading: false }
  }
}
</script>
