const intervals = {}

export default {
  data: () => ({ currentTime: new Date() }),
  mounted () {
    intervals[this._uid] = setInterval(() => {
      this.currentTime = new Date()
    }, 1000)
  },
  beforeDestroy () {
    clearInterval(intervals[this._uid])
    delete intervals[this._uid]
  }
}
