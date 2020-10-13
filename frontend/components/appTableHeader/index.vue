<template>
  <div class="app-table-header">
    <slot />
  </div>
</template>

<script>
export default {
  name: 'AppTableHeader'
}
</script>

<style scoped lang="scss">
@import "~@aeternity/aepp-components-3/src/styles/variables/colors";

.app-table-header {
  display: flex;
  flex-direction: column;
  background-color: #FFFFFF;
  border-bottom: 2px solid $color-neutral-positive-2;
}
.app-table-header > .app-table-row {
   padding: .6rem 0;
}
</style>
