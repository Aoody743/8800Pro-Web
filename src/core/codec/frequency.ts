import { SHX8800PRO } from '../constants/memory-map'

export function normalizeRadioFrequency(value: string, fallback = '') {
  const parsed = Number(value)
  if (!Number.isFinite(parsed)) return fallback
  if (parsed < SHX8800PRO.minFreqMhz || parsed >= SHX8800PRO.maxFreqMhz) return fallback
  let scaled = Math.round(parsed * 100000)
  scaled = Math.floor(scaled / 125) * 125
  return (scaled / 100000).toFixed(5)
}

export function encodeChannelFrequency(value: string) {
  const normalized = normalizeRadioFrequency(value)
  const bytes = new Uint8Array([0xff, 0xff, 0xff, 0xff])
  if (!normalized) return bytes
  let numeric = Number(normalized.replace('.', ''))
  for (let index = 0; index < 4; index += 1) {
    const pair = numeric % 100
    numeric = Math.floor(numeric / 100)
    bytes[index] = ((Math.floor(pair / 10) << 4) | (pair % 10)) & 0xff
  }
  return bytes
}

export function decodeChannelFrequency(payload: Uint8Array, offset: number) {
  const digits = Array.from(payload.slice(offset, offset + 4), (value) => ((value >> 4) & 0x0f) * 10 + (value & 0x0f))
  let numeric = 0
  for (let index = 3; index >= 0; index -= 1) {
    numeric = numeric * 100 + digits[index]
  }
  const text = String(numeric).padStart(8, '0')
  return `${text.slice(0, 3)}.${text.slice(3)}`
}

export function encodeVfoFrequency(value: string) {
  const bytes = new Uint8Array(8)
  bytes.fill(0xff)
  const normalized = normalizeRadioFrequency(value)
  if (!normalized) return bytes
  let numeric = Number(normalized.replace('.', ''))
  for (let index = 7; index >= 0; index -= 1) {
    bytes[index] = numeric % 10
    numeric = Math.floor(numeric / 10)
  }
  return bytes
}

export function decodeVfoFrequency(payload: Uint8Array, offset = 0) {
  let numeric = ''
  for (let index = 0; index < 8; index += 1) {
    numeric += String(payload[offset + index] % 10)
  }
  return `${numeric.slice(0, 3)}.${numeric.slice(3)}`
}

export function encodeOffset(value: string) {
  const parts = value.split('.')
  const integer = Number(parts[0] || 0)
  const decimal = Number((parts[1] || '').padEnd(4, '0').slice(0, 4))
  let numeric = integer * 10000 + decimal
  const bytes = new Uint8Array(7)
  bytes.fill(0xff)
  for (let index = 6; index >= 0; index -= 1) {
    bytes[index] = numeric % 10
    numeric = Math.floor(numeric / 10)
  }
  return bytes
}

export function decodeOffset(payload: Uint8Array, offset: number) {
  let text = ''
  for (let index = 0; index < 7; index += 1) {
    text += String(payload[offset + index] % 10)
  }
  return `${text.slice(0, 3)}.${text.slice(3)}`
}

export function encodeFmFrequency(freq: number) {
  const bytes = new Uint8Array(2)
  if (freq > 0) {
    bytes[0] = freq & 0xff
    bytes[1] = (freq >> 8) & 0xff
  }
  return bytes
}

export function decodeFmFrequency(payload: Uint8Array, offset: number) {
  if (payload[offset] === 0xff || payload[offset + 1] === 0xff) return 0
  const value = payload[offset] + (payload[offset + 1] << 8)
  return value >= 650 && value <= 1080 ? value : 0
}
