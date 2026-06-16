import { decode, encode } from 'gb2312'

export function encodeRadioText(input: string, maxBytes: number, fill = 0xff) {
  const bytes = new Uint8Array(maxBytes)
  bytes.fill(fill)
  let cursor = 0
  for (const char of input.trim()) {
    const encoded = encode(char, { replacement: '?' })
    if (cursor + encoded.length > maxBytes) break
    bytes.set(encoded, cursor)
    cursor += encoded.length
  }
  return bytes
}

export function decodeRadioText(payload: Uint8Array, offset: number, maxBytes: number) {
  const slice = payload.slice(offset, offset + maxBytes)
  const end = slice.findIndex((value) => value === 0xff || value === 0)
  const effective = end >= 0 ? slice.slice(0, end) : slice
  return decode(effective, { replacement: '?' }).trim()
}

export function encodeCallSign(input: string) {
  return input
    .toUpperCase()
    .replace(/[^0-9A-Z]/g, '')
    .slice(0, 6)
}
