<template>
  <div class="account-group">
    <slot />
  </div>
</template>
<script>

export default {
  name: 'AccountGroup'
}
</script>
<style scoped lang="scss">
  .account-group {
    & .account:first-child {
      position: relative;
      margin-bottom: .3rem;
      &:after {
        content: '';
        width: .5rem;
        height: .5rem;
        background-image: url('triangle.svg');
        background-repeat: no-repeat;
        position: absolute;
        bottom: -.4rem;
        left: 1.35rem;
        @media (max-width: 450px) {
          left: 1.6rem;
          bottom: -.2rem;
        }
      }
    }
  }
  .account-group > .account {
    @media (max-width: 450px) {
      flex-direction: row;
    }
  }
</style>
