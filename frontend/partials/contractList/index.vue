<template>
  <AppTable class="contract-list">
    <slot />
  </AppTable>
</template>
<script>
import AppTable from '../../components/appTable'
export default {
  name: 'ContractList',
  components: { AppTable }
}
</script>

<style lang="scss" scoped>
.contract-list {
  @media (min-width: 550px) {
    border-radius: .4rem;
    box-shadow: 0 0 16px 0 rgba(27,68,121,0.10);
    overflow: hidden;
  }
}
</style>
