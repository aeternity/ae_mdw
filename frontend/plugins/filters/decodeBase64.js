export default function decodeBase64 (payload) {
  try {
    if (process.server) {
      return Buffer.from(payload, 'base64').toString('utf-8')
    }
    return atob(payload)
  } catch (error) {
  }
  return payload
}
