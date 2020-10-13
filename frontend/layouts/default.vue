<template>
  <div class="app">
    <AppHeader />
    <AppView>
      <nuxt />
    </AppView>
  </div>
</template>
<script>
import AppHeader from '../partials/appHeader'
import AppView from '../partials/appView'
export default {
  components: {
    AppHeader,
    AppView
  }
}
</script>
