<template>
  <span
    :class="type"
    class="label-type"
  >
    {{ title }}
  </span>
</template>
<script>
export default {
  name: 'LabelType',
  props: {
    title: {
      type: String,
      required: true
    }
  },
  computed: {
    type () {
      if (this.title.includes('OUT')) {
        return 'red'
      } else if (this.title.includes('IN')) {
        return 'green'
      } else {
        switch (this.title.match(/[^\s]+/g)[0]) {
          case 'Spend':
            return 'red'
          case 'Name':
            return 'grey'
          case 'Contract':
            return 'green'
          case 'Oracle':
            return 'purple'
          default:
            return 'black'
        }
      }
    }
  }
}
</script>
<style scoped lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  @import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";
  .label-type {
    display: table-caption;
    padding: 0.6rem;
    text-transform: uppercase;
    color: white;
    border-radius: 0 5px 5px 0;
    font-weight: bold;
    @extend %face-uppercase-xs;
  }
  .label-type.red {
    background-color: $color-red;
  }
  .label-type.green {
    background-color: $color-alternative;
  }
  .label-type.black {
    background-color:  $color-neutral-negative-3;
  }
  .label-type.purple {
    background-color: $color-secondary;
  }
  .label-type.grey {
    background-color: $color-neutral;
  }

</style>
