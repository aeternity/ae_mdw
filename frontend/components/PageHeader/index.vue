<template>
  <section class="app-page-header">
    <div class="app-page-header-container">
      <h1
        v-if="isMain"
        class="app-page-header-title"
      >
        {{ title }}
      </h1>
      <h2
        v-else
        class="app-page-header-title"
      >
        {{ title }}
      </h2>
      <PageNav
        v-if="hasNav"
        :prev="prev"
        :next="next"
      />
    </div>
    <div
      v-if="hasCrumbs"
      class="app-page-header-container"
    >
      <BreadCrumbs
        :root="root"
        :page="page"
        :subpage="subpage"
      />
    </div>
  </section>
</template>
<script>
import PageNav from '../PageNav'
import BreadCrumbs from '../breadCrumbs'

export default {
  name: 'PageHeader',
  components: {
    PageNav,
    BreadCrumbs
  },
  props: {
    title: {
      type: String,
      required: true
    },
    isMain: {
      type: Boolean,
      default: true
    },
    hasNav: {
      type: Boolean,
      default: false
    },
    hasCrumbs: {
      type: Boolean,
      default: false
    },
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
    },
    prev: {
      type: String,
      default: ''
    },
    next: {
      type: String,
      default: ''
    }
  }
}
</script>
<style lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  @import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";

    .app-page-header {
      background-color: transparent;
      margin: 0 -3rem;
      margin-bottom: -2.5rem;
      padding: .6rem 3rem 3rem;
      @media (min-width: 768px) {
        padding: .6rem 0;
        margin: 0;
      }
      &-title {
        font-size: 1.7rem;
        margin-bottom: 0;
        line-height: 1;
        text-transform: capitalize;
        font-weight: normal;
      }
      &-container {
        display: flex;
        justify-content: space-between;
      }
    }

</style>
