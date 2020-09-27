<template>
  <div
    class="generations-wrapper"
  >
    <PageHeader
      title="Generations"
      :has-crumbs="true"
      :page="{to: '/generations', name: 'Generations'}"
    />
    <Generations>
      <nuxt-link
        v-for="(generation, number) in Object.values(generations).reverse()"
        :key="number"
        :to="`/generations/${generation.height}`"
        class="generation-link"
      >
        <Generation
          :data="generation"
        />
      </nuxt-link>
    </Generations>
    <LoadMoreButton @update="loadMoreGen" />
  </div>
</template>

<script>

import { mapState } from 'vuex'
import Generations from '../../partials/generations'
import Generation from '../../partials/generation'
import PageHeader from '../../components/PageHeader'
import LoadMoreButton from '../../components/loadMoreButton'

export default {
  name: 'AppGenerations',
  components: {
    Generations,
    Generation,
    PageHeader,
    LoadMoreButton
  },
  data () {
    return {
      limitGen: 10
    }
  },
  computed: {
    ...mapState('generations', [
      'generations'
    ])
  },
  async mounted () {
    if (!Object.keys(this.$store.state.generations.generations).length) {
      await this.$store.dispatch('height')
      this.$store.dispatch('generations/getLatestGenerations', 10)
    }
  },
  methods: {
    loadMoreGen () {
      this.$store.dispatch('generations/getLatestGenerations', this.limitGen)
    }
  }
}
</script>

<style scoped lang='scss'>
  .generations-wrapper {
    .generation-link {
      &:hover {
        color: #000000;
      }
    }
  }
</style>
