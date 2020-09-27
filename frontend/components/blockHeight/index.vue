<template>
  <nuxt-link
    :to="`/generations/${value}`"
  >
    <span class="block-height">
      {{ value }}
    </span>
  </nuxt-link>
</template>
<script>
export default {
  name: 'BlockHeight',
  props: {
    value: {
      type: Number,
      required: true
    }
  }
}
</script>
<style lang="scss" scoped>
  .block-height {
    font-size: 1.7rem;
    margin-left: .6rem;
    font-family: "Inter UI", sans-serif;
  }
</style>
