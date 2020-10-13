<template>
  <div class="confirmations">
    <span class="confirmations-num">
      {{ maxHeight - height }}
    </span>
    <span class="confirmations-name">
      <span>
        Block
      </span>
      <br>
      <span>
        Confirmations
      </span>
    </span>
  </div>
</template>
<script>
export default {
  name: 'Confirmations',
  props: {
    maxHeight: {
      type: Number,
      required: true
    },
    height: {
      type: Number,
      required: true
    }
  }
}
</script>
<style lang="scss" scoped>
@import "~@aeternity/aepp-components-3/src/styles/variables/colors";
@import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";
.confirmations {
  display: flex;
  flex-direction: column;
  color: $color-neutral;
  padding-left: .6rem;
  @media (min-width: 450px) {
    font-size: 1.7rem;
    display: block;
    padding: 0;

  }
  &:before {
    @media (min-width: 450px) {
      content: '\2014';
      margin-right: -.5rem;
    }
  }
  &-num {
    @media (max-width: 449px) {
      order: 2;
      &:after {
        content: 'Blocks';
        font-size: 0.6875rem;
        font-weight: 500;
        text-transform: uppercase;
        letter-spacing: .05rem;
      }
    }
  }

  &-name {
    text-transform: uppercase;
    @media (max-width: 449px) {
      order: 1;
      display: block;
      font-weight: 500;
      color: $color-neutral-negative-3;
      font-size: 0.6875rem;
      font-weight: 500;
      letter-spacing: .05rem;
      margin-bottom: .2rem;
      & span:first-child {
        display: none;
      }
    }
    @media (min-width: 450px) {
      font-size: .6875rem;
      line-height: .75rem;
      font-weight: bold;
      display: inline-block;
      color: $color-neutral;
    }
  }
}
</style>
