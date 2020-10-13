<template>
  <span class="network-name">
    <span class="container">
      {{ name }}
    </span>
  </span>
</template>

<script>

export default {
  computed: {
    name () {
      return this.$store.state.networkName
    }
  }
}
</script>

<style lang="scss" scoped>
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  @import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";

  .network-name {
    display: flex;
    justify-content: flex-end;
    color: $color-white;

    .container{
      @extend %face-sans-xs;
      @extend %face-uppercase-xs;
      font-weight:500;
      padding:1rem 1.2rem;
      background-color: $color-primary;
      border-radius: 0.3rem;
    }
  }
</style>
