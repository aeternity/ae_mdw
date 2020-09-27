<template>
  <div class="load-more-button-wrapper">
    <AppButton
      face="round"
      fill="neutral"
      extend
      @click.native="loadMore()"
    >
      Load More
    </AppButton>
  </div>
</template>
<script>
import AppButton from '../appButton'

export default {
  name: 'LoadMoreButton',
  components: {
    AppButton
  },
  methods: {
    loadMore () {
      this.$emit('update')
    }
  }
}
</script>
<style scoped lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  .load-more-button-wrapper {
    margin-top: 2rem;
    position: relative;
    min-height: 60px;
    &::after {
      content: "";
      display: block;
      position: absolute;
      width: 100%;
      left: 0;
      top: 50%;
      border-bottom: 2px solid $color-neutral-positive-2;
      transform: translateY(-50%);
    }
  }
</style>
