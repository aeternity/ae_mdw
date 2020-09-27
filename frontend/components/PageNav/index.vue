<template>
  <nav
    class="page-nav"
  >
    <ul class="page-nav-list">
      <li
        class="page-nav-list-item prev"
      >
        <nuxt-link
          v-if="prev"
          :to="prev"
        >
          <span class="visually-hidden">
            previous page
          </span>
          <AppIcon name="back" />
        </nuxt-link>
        <span
          v-else
          class="disabled"
        >
          <AppIcon name="back" />
        </span>
      </li>
      <li class="page-nav-list-item next">
        <nuxt-link
          v-if="next"
          :to="next"
          @click="goTo"
        >
          <span class="visually-hidden">
            next page
          </span>
          <AppIcon name="back" />
        </nuxt-link>
        <span
          v-else
          class="disabled"
        >
          <AppIcon name="back" />
        </span>
      </li>
    </ul>
  </nav>
</template>
<script>
import AppIcon from '../appIcon'

export default {
  name: 'PageNav',
  components: {
    AppIcon
  },
  props: {
    prev: {
      type: String,
      default: ''
    },
    next: {
      type: String,
      default: ''
    }
  },
  methods: {
    goTo () {
      this.$emit('get')
    }
  }
}
</script>
<style lang="scss" scoped>
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  @import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";
  .page-nav {
    display: flex;
    align-items: center;
    &-list {
      list-style: none;
      margin: 0;
      padding: 0;
      display: flex;
      align-items: center;
      &-item {
        display: flex;
        align-items: center;
        font-size: 1.3rem;
        text-transform: capitalize;
        &.prev {
          margin-right: 1rem;
        }
        &.next .app-icon {
          transform: rotate(180deg);
        }
        & .disabled {
          color: $color-neutral-negative-1;
          cursor: not-allowed;
        }
      }
    }
  }
  .visually-hidden {
    position: absolute !important;
    clip: rect(1px 1px 1px 1px); /* IE6, IE7 */
    clip: rect(1px, 1px, 1px, 1px);
    padding:0 !important;
    border:0 !important;
    height: 1px !important;
    width: 1px !important;
    overflow: hidden;
  }
</style>
