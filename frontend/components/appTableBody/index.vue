<template>
  <div class="app-table-body">
    <slot />
  </div>
</template>

<script>
export default {
  name: 'AppTableBody'
}
</script>

<style scoped lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  .app-table-body {
    display: flex;
    flex-wrap: wrap;
  }
  .app-table-body > .app-table-row {
    width: 50%;
    margin-top: 0;
    padding-top: 0;
    &:first-child {
      border-top: none;
      margin-top: 0;
      padding-top: 0;
    }
    &:not(.extend) {
      border-left: 2px solid $color-neutral-positive-2;
      @media (min-width: 550px) {
        border-left: none;
      }
    }
    @media (min-width: 550px) {
      width: 100%;
      border-left: none;
      border-bottom: 2px solid $color-neutral-positive-2;
    }
    &.extend {
      width: 100%;
      border-left: none;
      &:not(:last-child) {
        border-bottom: 2px solid $color-neutral-positive-2;
      }
    }
  }
</style>
