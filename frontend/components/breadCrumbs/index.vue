<template>
  <nav class="breadcrumbs">
    <ul class="breadcrumbs-list">
      <li class="breadcrumbs-list-item">
        <NuxtLink
          to="/"
          active-class="active"
          exact
        >
          Home
        </NuxtLink>
      </li>
      <li
        v-if="page.to"
        class="breadcrumbs-list-item"
      >
        <NuxtLink
          :to="page.to"
          active-class="active"
          exact
        >
          {{ page.name }}
        </NuxtLink>
      </li>
      <li
        v-if="subpage.to"
        class="breadcrumbs-list-item"
      >
        <NuxtLink
          :to="subpage.to"
          active-class="active"
          exact
        >
          {{ subpage.name }}
        </NuxtLink>
      </li>
    </ul>
  </nav>
</template>
<script>
export default {
  name: 'BreadCrumbs',
  props: {
    root: {
      type: Object,
      default: () => {
        return { to: '/', name: 'home' }
      }
    },
    page: {
      type: Object,
      default: () => {
        return { to: '', name: '' }
      }
    },
    subpage: {
      type: Object,
      default: () => {
        return { to: '', name: '' }
      }
    }
  }
}
</script>
<style lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  @import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";

    .breadcrumbs {
      width: 100%;
      padding: .3rem 0;

      &-list {
        list-style: none;
        margin: 0;
        padding: 0;
        width: 100%;
        display: flex;

          &-item {
            @extend %face-sans-s;
            &:not(:last-child) {
              &:after {
                content: '>';
                text-align: center;
                margin-right: .25rem;
              }
            }
            & .active {
              color: $color-neutral-negative-1;
              &:hover {
                color: $color-primary;
              }
            }
          }
      }
    }
</style>
