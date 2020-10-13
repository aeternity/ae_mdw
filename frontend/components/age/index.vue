<template>
  <time
    class="age"
    :datetime="time | dateTime"
  >
    <template v-for="(item, idx) in items">
      {{ idx ? ' ' : '' }}
      <span
        :key="`${item.unit}-number`"
        class="number"
      >
        {{ item.number }}
      </span>
      <sub
        :key="item.unit"
        class="unit"
      >
        {{ item.unit }}
      </sub>
    </template>
  </time>
</template>

<script>
import currentTime from '../../mixins/currentTime'
export default {
  name: 'Age',
  filters: {
    dateTime (value) {
      if (!value) return ''
      value = new Date(value).toISOString()
      return value
    }
  },
  mixins: [currentTime],
  props: {
    time: {
      type: Number,
      required: true
    }
  },
  computed: {
    items () {
      let age = this.currentTime - this.time
      let t = age < 0 ? 0 : age
      t = Math.floor(t / 1000)
      const values = []
      values.unshift({ unit: 'SECS', number: t % 60 })
      t = Math.floor(t / 60)
      values.unshift({ unit: 'MIN', number: t % 60 })
      t = Math.floor(t / 60)
      values.unshift({ unit: 'HRS', number: t % 24 })
      t = Math.floor(t / 24)
      values.unshift({ unit: 'DAYS', number: t % 30 })
      t = Math.floor(t / 30)
      values.unshift({ unit: 'MONTHS', number: t % 12 })
      t = Math.floor(t / 12)
      values.unshift({ unit: 'YEARS', number: t })
      while (values.length && !values[0].number) values.shift()
      return values.map((v, idx) => {
        if (!idx) return v
        return {
          unit: v.unit,
          number: String(v.number).padStart(2, '0')
        }
      }).slice(0, 2)
    }
  }
}
</script>

<style scoped lang="scss">
  .age {
    & * {
      display: inline-block;
      vertical-align: baseline;
    }
    & .unit {
      font-size: .7em;
      margin-left: -.7em;
      text-decoration: none;
      position: initial;
    }
  }
</style>
