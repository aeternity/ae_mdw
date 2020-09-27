import BigNumber from 'bignumber.js'

export default function (value) {
  if (value < 10 ** 18) {
    return value + ' ættos'
  }
  return new BigNumber(value).shiftedBy(-18).toString() + ' AE'
}
