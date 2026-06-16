import type { Channel } from '../core/models/radio'

export interface SatelliteMode {
  name: string
  mode: string
  uplink: string
  downlink: string
  callsign: string
  status: string
  satnogsId: string
  tone: string
}

interface RawSatellite {
  name?: string
  mode?: string
  uplink?: string
  downlink?: string
  callsign?: string
  status?: string
  satnogs_id?: string | number
}

const URLS = [
  'https://raw.githubusercontent.com/palewire/amateur-satellite-database/main/data/amsat-all-frequencies.json',
  'https://cdn.jsdelivr.net/gh/palewire/amateur-satellite-database/data/amsat-all-frequencies.json',
]

export async function fetchSatelliteModes() {
  let lastError: unknown
  for (const url of URLS) {
    try {
      const response = await fetch(url)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const raw = (await response.json()) as RawSatellite[]
      return raw.map(normalizeMode).filter((mode) => mode.name)
    } catch (error) {
      lastError = error
    }
  }
  throw lastError instanceof Error ? lastError : new Error('卫星数据下载失败')
}

export function createSatelliteChannels(mode: SatelliteMode, options: { doppler: boolean; uStep: number; vStep: number }) {
  const downlink = parseFrequency(mode.downlink)
  const uplink = parseFrequency(mode.uplink) || downlink
  if (!downlink || !uplink) throw new Error('当前卫星频率不适合写入信道')
  const base: Channel = {
    id: 0,
    rxFreq: downlink.toFixed(5),
    txFreq: uplink.toFixed(5),
    rxTone: 'OFF',
    txTone: mode.tone || 'OFF',
    txPower: 0,
    bandwidth: 0,
    scanAdd: 0,
    busyLock: 0,
    pttid: 0,
    signalGroup: 0,
    name: mode.name.slice(0, 12),
    visible: true,
  }
  if (!options.doppler) return [base]
  return [-2, -1, 0, 1, 2].map((level) => ({
    ...base,
    rxFreq: calcDoppler(downlink, options.uStep, options.vStep, level, 1).toFixed(5),
    txFreq: calcDoppler(uplink, options.uStep, options.vStep, level, 0).toFixed(5),
    name: `${base.name}${level < 0 ? `-A${Math.abs(level)}` : level > 0 ? `-L${level}` : ''}`.slice(0, 12),
  }))
}

function normalizeMode(raw: RawSatellite): SatelliteMode {
  const mode = String(raw.mode ?? '')
  return {
    name: String(raw.name ?? ''),
    mode,
    uplink: clean(raw.uplink),
    downlink: clean(raw.downlink),
    callsign: clean(raw.callsign),
    status: clean(raw.status),
    satnogsId: clean(raw.satnogs_id),
    tone: matchTone(mode),
  }
}

function clean(value: unknown) {
  return String(value ?? '').replace(/\s+/g, ' ').trim()
}

function matchTone(mode: string) {
  const match = mode.match(/\b(?:tone|ctcss)\s+(\d+(?:\.\d+)?)\s*hz\b/i)
  return match ? `${Number(match[1]).toFixed(1)}` : ''
}

function parseFrequency(value: string) {
  const match = value.match(/\d+(?:\.\d+)?/)
  if (!match) return 0
  const parsed = Number(match[0])
  return parsed > 520 || parsed < 100 ? 0 : parsed
}

function calcDoppler(band: number, uStep: number, vStep: number, level: number, direction: 0 | 1) {
  if (band < 300) return direction === 1 ? band - 0.0005 * vStep * level : band + 0.0005 * vStep * level
  return direction === 1 ? band - 0.0005 * uStep * level : band + 0.0005 * uStep * level
}
