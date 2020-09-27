<template>
  <div
    :class="openMenu ? 'open' : ''"
    class="app-nav-accordion"
  >
    <button
      class="app-nav-accordion-btn"
      @click="toggleNav"
    >
      <AppIcon :name="icon" />
    </button>
    <div
      class="app-nav-accordion-content"
      @touchmove="prevent"
    >
      <button
        class="app-nav-accordion-btn close"
        @click="toggleNav"
      >
        <AppIcon name="close" />
      </button>
      <slot />
    </div>
  </div>
</template>
<script>
import AppIcon from '../appIcon'
export default {
  name: 'AppNavAccordion',
  components: {
    AppIcon
  },
  props: {
    icon: {
      type: String,
      default: 'burger'
    }
  },
  data () {
    return { openMenu: false }
  },
  methods: {
    toggleNav () {
      this.openMenu = !this.openMenu
    },
    prevent (event) {
      event.preventDefault()
      event.stopPropagation()
    }
  }
}
</script>
<style scoped lang="scss">
    @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
    .app-nav-accordion {
      position: relative;
      width: 2rem;
      height: 2rem;
      @media (min-width: 769px) {
        width: auto;
        height: auto;
        margin: auto 0 auto -1rem;
      }
    }
    .app-nav-accordion-btn {
        color: #ffffff;
        font-size: 1.5rem;
        line-height: 0;
        padding: 0;
        background-color: transparent;
        border: none;
        @media (min-width: 769px) {
          display: none;
        }
      &.close {
        position: absolute;
        top: .8rem;
        right: 1.2rem;
      }
    }
    .app-nav-accordion-content {
      @media (max-width: 768px) {
      display: flex;
      flex-direction: column;
      justify-content: center;
      margin: auto 0;
      position: fixed;
      top: 0;
      left: 0;
      overflow: hidden;
      height: 100vh;
      width: 100%;
      z-index: 10;
      font-size: 1.7rem;
      background-color: $color-neutral-minimum;
      opacity: 0;
      transform: translateY(-200%);
      transition: all .3s ease-in-out;
      }
    }
    .open .app-nav-accordion-content {
        transform: translateY(-0%);
        opacity: 1;
        z-index: 10;
    }

</style>
