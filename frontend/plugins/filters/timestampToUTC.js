export default function (timestamp) {
  if (timestamp) {
    return new Date(timestamp).toUTCString()
  }
  return 0
}
