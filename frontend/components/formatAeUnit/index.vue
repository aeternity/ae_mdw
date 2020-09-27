<template>
  <span class="format-ae-unit">
    {{ value | prefixAmount }}
  </span>
</template>
<script>
import prefixAmount from '../../plugins/filters/prefixedAmount'

export default {
  name: 'FormatAeUnit',
  filters: {
    prefixAmount
  },
  props: {
    value: {
      type: Number,
      required: true
    }
  }
}
</script>
<style scoped lang="scss">
    .format-ae-unit {
        & .unit {
          font-size: .7em;
          margin-left: -.7em;
          text-decoration: none;
        }
    }

</style>
