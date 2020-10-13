<template>
  <nav class="app-nav">
    <slot />
  </nav>
</template>

<script>
export default {
  name: 'AppNav'
}
</script>

<style scoped>
  .app-nav {
    display: flex;
    flex-direction: column;
  }

</style>
