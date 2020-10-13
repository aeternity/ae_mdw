<template>
  <div
    :class="{
      details
    }"
    class="app-table"
  >
    <slot />
  </div>
</template>
<script >
export default {
  name: 'AppTable',
  props: {
    /**
     * Extend the table row full width on mobile
     */
    details: {
      type: Boolean,
      default: false
    }
  }
}
</script>
<style lang="scss" scoped>
  .app-table{
    display: flex;
    flex-direction: column
  }
</style>
