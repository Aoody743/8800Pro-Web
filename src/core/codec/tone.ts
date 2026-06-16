import { DCS_CODES } from '../constants/choices'

export function encodeTone(value: string) {
  const bytes = new Uint8Array([0, 0])
  if (!value || value === 'OFF') return bytes
  if (value.startsWith('D')) {
    const index = DCS_CODES.indexOf(value as (typeof DCS_CODES)[number])
    bytes[0] = index >= 0 ? index + 1 : 0
    bytes[1] = 0
    return bytes
  }
  const numeric = Number(value.replace('.', ''))
  if (!Number.isFinite(numeric)) return bytes
  bytes[0] = numeric & 0xff
  bytes[1] = (numeric >> 8) & 0xff
  return bytes
}

export function decodeTone(payload: Uint8Array, offset: number) {
  const first = payload[offset]
  const second = payload[offset + 1]
  if (second === 0) {
    if (first > 0 && first <= DCS_CODES.length) return DCS_CODES[first - 1]
    return 'OFF'
  }
  if (first !== 0 && first !== 0xff) {
    const text = String((second << 8) + first)
    return `${text.slice(0, -1)}.${text.slice(-1)}`
  }
  return 'OFF'
}
