<template>
  <svg-icon
    :name="`${name}/${name}`"
    class="app-icon"
  />
</template>

<script>
export default {
  name: 'AppIcon',
  props: {
    name: {
      type: String,
      required: true
    }
  }
}
</script>
<style lang="scss">
  .app-icon {
    width: 1em;
    height: 1em;
    fill: currentColor;
    display: inline-block;
  }
</style>
