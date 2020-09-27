<template>
  <div
    :class="{
      [type]: Boolean(type)
    }"
    class="app-definition"
  >
    <div
      v-if="title"
      class="app-definition-title"
    >
      {{ title }}
    </div>
    <div class="app-definition-content">
      <slot />
    </div>
  </div>
</template>

<script>
export default {
  name: 'AppDefinition',
  props: {
    /**
     * Fill property changes the color state of the button
     * select something between: `primary, secondary, neutral, alternative`
     */
    type: {
      type: String,
      validator: value => [
        'block',
        'list'
      ].includes(value),
      default: 'block'
    },
    title: {
      type: String,
      default: ''
    }
  }
}
</script>

<style scoped lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  @import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";
  .app-definition {
    display: flex;
    margin: 0;
    flex-direction: column;
    align-items: baseline;
    width: 100%;
  }
  .app-definition-title {
    font-weight: 500;
    @extend %face-uppercase-xs;
  }
  .app-definition-content {
    color: #76818C;
    word-break: break-all;
    @extend %face-mono-s;
  }
  .app-definition.block {
    padding: .6rem;
  }
  .app-definition.list {
    background-color: $color-neutral-positive-3;
    padding: .6rem;
    align-items: flex-start;
    height: 100%;
    @media (min-width: 550px) {
      flex-direction: row;
      padding: 0;
    }
    & .app-definition-title {
      @media (min-width: 550px) {
        text-align: right;
        width: 25%;
        padding: .6rem;
      }
    }
    & .app-definition-content {
      height: 100%;
      @media (min-width: 550px) {
        padding: .8rem;
        background-color: #FFFFFF;
        width: 75%;
      }
    }
  }
</style>
