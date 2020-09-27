<template>
  <div
    :class="{
      extend
    }"
    class="app-table-cell"
  >
    <slot />
  </div>
</template>
<script>
export default {
  name: 'AppTableCell',
  props: {
    extend: {
      type: Boolean,
      default: false
    }
  }
}
</script>
<style scoped lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";

  .app-table-cell {
    display: flex;
    flex-direction: column;
    height: 100%;
    width: 100%;
    @media (min-width: 550px) {
      width: 50%;
    }
    &:not(:first-child) {
      @media (min-width: 550px) {
        border-left: 2px solid $color-neutral-positive-2;
      }
    }
  }
  /*
  * When cell should take the full width
  */
  .app-table-cell.extend {
    margin-bottom:  auto;
    width: 100%;
    @media (min-width: 550px) {
      margin-right: auto;
    }
  }
</style>
