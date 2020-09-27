<template>
  <article class="micro-blocks">
    <slot />
  </article>
</template>
<script>
export default {
  name: 'MicroBlocks'
}
</script>
<style lang="scss">
  .micro-blocks {
      margin-top: 2rem;
  }
</style>
