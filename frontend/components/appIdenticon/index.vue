<template>
  <canvas
    ref="blockie"
    class="app-identicon"
  />
</template>
<script>
import { renderIcon } from '@download/blockies'

/**
   * Displays the representation of an aeternity address as an identicon
   * @link https://npmjs.com/package/@download/blockies
   */
export default {
  name: 'AppIdenticon',
  props: {
    /**
       * Address of the wallet for which the identicon is
       * going to generate a blockies from.
       */
    address: {
      type: String,
      required: true
    }
  },
  watch: {
    address () {
      this.render()
    }
  },
  mounted () {
    this.render()
  },
  methods: {
    render () {
      renderIcon({ seed: this.address }, this.$refs.blockie)
    }
  }
}
</script>
<style lang="scss" scoped>
  .app-identicon {
    display: inline-block;
    border-radius: 50%;
    height: 2rem;
  }
</style>
