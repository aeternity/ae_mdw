<template>
  <a
    v-if="external"
    :href="to"
    target="_blank"
    class="app-nav-link"
  >
    {{ externalValue }}
  </a>
  <NuxtLink
    v-else
    :to="to"
    class="app-nav-link"
    active-class="active"
    :exact="exact"
  >
    <slot />
  </NuxtLink>
</template>

<script>
export default {
  name: 'AppNavLink',
  props: {
    to: {
      type: String,
      required: true
    },
    external: {
      type: Boolean,
      required: false,
      default: false
    },
    externalValue: {
      type: String,
      required: false,
      default: ''
    },
    exact: {
      type: Boolean,
      required: false,
      default: false
    }
  }
}
</script>

<style scoped lang="scss">
 .app-nav-link {
   color: #76818C;
   line-height: 1;
   padding-left: 1.5rem;
   margin: .5rem 0;
   margin-left: .2rem;
   &.active {
     color: #FFFFFF;
     border-left: 2px solid #F7296E;
   }
 }
</style>
