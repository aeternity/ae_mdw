<template>
  <div
    :class="{ [width]: Boolean(width)
    }"
    class="app-table-row-column"
  >
    <slot />
  </div>
</template>

<script>
export default {
  name: 'AppTableRowColumn',
  props: {
    /**
     * Set the width of the column to expand, default is half (medium)
     */
    width: {
      type: String,
      validator: value => [
        'large',
        'medium',
        'small'
      ].includes(value),
      default: 'medium'
    }
  }
}
</script>

<style scoped lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  .app-table-row-column {
    display: flex;
    flex-direction: column;
    @media (min-width: 550px) {
      flex-direction: row;
    }
    @media (min-width: 1600px) {
      &:first-child {
        margin-right: auto;
      }
    }

  }
  .app-table-row-column > .app-table-cell {
    &:not(:last-child):first-child {
      @media (max-width: 550px) {
      border-bottom: 2px solid $color-neutral-positive-2;
      }
    }
    &:not(:first-child){
      @media (min-width: 550px) {
        border-left: 2px solid $color-neutral-positive-2;
      }
    }
  }
  .app-table-row-column:not(:first-child) {
    border-left:  2px solid $color-neutral-positive-2;
  }
  .app-table-row-column > .app-table-row {
    @media (min-width: 1600px) {
      width: 100%;
    }
  }

  .app-table-row-column > .app-table-row {
    width: 100%;
    padding: 0;
    @media (min-width: 550px) {
      margin-bottom: 0;
      border-left: none;
    }
  }
  .app-table-row-column > .app-table-row > .app-table-cell {
    border-bottom: 2px solid $color-neutral-positive-2;
    width: 100%;
  }
  .app-table-row-column.large{
    width:50%;
    @media (min-width: 550px) {
      width:75%;
    }
  }
  .app-table-row-column.medium{
    width:50%;
    @media (min-width: 1600px) {
      width: 25%;
    }
  }
  .app-table-row-column.small{
    width:50%;
    @media (min-width: 550px) {
      width: 25%;
    }
  }
  .app-table-row-column.small > .app-table-cell {
    width: 100%;
  }
</style>
