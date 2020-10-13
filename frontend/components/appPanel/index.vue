<template>
  <div class="app-panel">
    <slot />
  </div>
</template>

<script>
export default {
  name: 'AppPanel'
}
</script>

<style scoped lang="scss">
.app-panel {
  border-radius: 10px;
  box-shadow: 0 4px 8px 2px rgba(60, 60, 60, 0.1);
  box-sizing: border-box;
  overflow: hidden;
  background-color: #FFFFFF;
}
</style>
