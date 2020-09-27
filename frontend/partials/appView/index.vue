<template>
  <div class="app-view">
    <slot />
  </div>
</template>
<script>
export default {
  name: 'AppView'
}
</script>
<style lang="scss">
  .app-view {
    display: flex;
    flex-direction: column;
    width: 100%;
    padding: 0 .8rem;
    margin-bottom: 3rem;
    @media (min-width: 450px) {
    padding: 0 2rem;
  }
    @media (min-width: 769px) {
      width: 80%;
      margin-left: auto;
      padding: 0 5%;
    }
    @media (min-width: 1080px) {
      width: 85%;
      margin-left: auto;
      padding: 0 5%;
    }
  }
</style>
