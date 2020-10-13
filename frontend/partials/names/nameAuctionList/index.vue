<template>
  <AppTable class="name-auction-list">
    <slot />
  </AppTable>
</template>
<script>
import AppTable from '../../../components/appTable'
export default {
  name: 'NameAuctionList',
  components: { AppTable }
}
</script>

<style lang="scss" scoped>
.name-auction-list {
  margin-top: 2em;
  @media (min-width: 550px) {
    border-radius: .4rem;
    box-shadow: 0 0 16px 0 rgba(27,68,121,0.10);
    overflow: hidden;
  }
}
</style>
