<template>
  <button
    :class="{
      [fill]: Boolean(fill),
      [`color-${color}`]: Boolean(color),
      [face]: Boolean(face),
      extend
    }"
    class="app-button"
    type="button"
  >
    <slot />
  </button>
</template>
<script>
export default {
  name: 'AppButton',
  props: {
    /**
     * Fill property changes the color state of the button
     * select something between: `primary, secondary, neutral, alternative`
     */
    fill: {
      type: String,
      validator: value => [
        'primary',
        'secondary',
        'neutral',
        'alternative'
      ].includes(value),
      default: 'neutral'
    },

    /**
     * color property changes the text color of the button
     * select something between: ` primary, secondary, neutral, alternative`
     */
    color: {
      type: String,
      validator: value => [
        'primary',
        'secondary',
        'neutral',
        'alternative'
      ].includes(value),
      default: 'neutral'
    },

    /**
     * Face applies a shape/form to
     * the current button, available options:
     * `round, flat, icon, toolbar`
     */
    face: {
      type: String,
      validator: value => [
        '',
        'round',
        'flat',
        'icon',
        'toolbar'
      ].includes(value),
      default: ''
    },

    /**
     * Extend the button full width
     */
    extend: {
      type: Boolean,
      default: false
    }
  }
}
</script>
<style lang="scss" scoped>
@import '~@aeternity/aepp-components-3/src/styles/variables/colors';
@import '~@aeternity/aepp-components-3/src/styles/placeholders/typography';

.app-button {
  user-select: none;
  position: relative;
  display: flex;
  max-width: 18rem;
  margin: auto;
  justify-content: center;
  align-items: center;
  font-family: inherit;
  font-weight: bold;
  border: none;
  height: 56px;
  cursor: pointer;
  outline: none;
  text-decoration: none;
  @extend %face-uppercase-base;
  border-radius: 32px;
  box-shadow: 0 0 16px $color-shadow-alpha-15;
  padding: 0 2rem;
  letter-spacing: em(1.3px);
  z-index: 1;

  &:hover,
  &:focus {
    text-decoration: none;
  }
  &:disabled {
    cursor: not-allowed;
    box-shadow: none;
    color: $color-neutral-positive-1;
  }
  &:active:not(:disabled) {
    opacity: 0.85;
  }

  > i {
    margin: 0 0.25rem;
  }
}

.app-button.extend {
  padding: 0;
  width: 100%;
}
</style>
