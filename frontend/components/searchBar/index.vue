<template>
  <div class="search-bar">
    <input
      v-model="query"
      :placeholder="placeholder"
      class="search-bar-input"
      type="text"
      @keyup.enter="processInput"
    >
    <button
      class="search-bar-button"
      @click="processInput"
    >
      <AppIcon name="search" />
    </button>
  </div>
</template>
<script>
import AppIcon from '../appIcon'

export default {
  name: 'SearchBar',
  components: {
    AppIcon
  },
  props: {
    placeholder: {
      type: String,
      default: 'Search'
    }
  },
  data () {
    return {
      query: ''
    }
  },
  methods: {
    processInput () {
      if (this.query.match(/^\d+$/)) {
        this.$router.push(`/generations/${this.query}`)
        this.query = ''
      } else if (this.query.match(/^th_[1-9A-HJ-NP-Za-km-z]{48,50}$/)) {
        this.$router.push(`/transactions/${this.query}`)
        this.query = ''
      } else if (this.query.match(/^ok_[1-9A-HJ-NP-Za-km-z]{48,50}$/)) {
        this.$router.push(`/oracles/queries/${this.query}`)
        this.query = ''
      } else if (this.query.match(/^ch_[1-9A-HJ-NP-Za-km-z]{48,50}$/)) {
        this.$router.push(`/channels/transactions/${this.query}`)
        this.query = ''
      } else if (this.query.match(/^ct_[1-9A-HJ-NP-Za-km-z]{48,50}$/)) {
        this.$router.push(`/contracts/transactions/${this.query}`)
        this.query = ''
      } else if (this.query.match(/^ak_[1-9A-HJ-NP-Za-km-z]{48,50}$/)) {
        this.$router.push(`/account/transactions/${this.query}`)
        this.query = ''
      } else {
        this.$router.push(`/names/${this.query}`)
        this.query = ''
      }
    }
  }
}
</script>
<style scoped lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  @import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";
  .search-bar {
    position: relative;
    width: 100%;
    display: flex;
    flex-direction: row;
    background-color: #FFFFFF;
    border-radius: .4rem;
    overflow: hidden;
    justify-content: center;
    align-items: center;
    &-input {
      width: 100%;
      border: none;
      padding: 1.3rem .6rem;
      color: $color-neutral-negative-1;
      @extend %face-sans-base;
    }

    &-button {
      border: none;
      background-color: transparent;
      cursor: pointer;
      justify-content: center;
      align-items: center;
      line-height: 0;
      padding: 1.3rem .6rem;
      font-size: 1.5rem;
      color: $color-neutral-negative-1;
    }
  }
</style>
