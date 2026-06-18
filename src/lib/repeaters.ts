import type { Channel } from '../core/models/radio'

export type RepeaterKind = '模拟' | '混合' | '数字' | '模拟/数字'

export interface RepeaterEntry {
  id: string
  region: string
  province: string
  provinceCode: number
  city: string
  cityCode: number
  area: string
  name: string
  callSign?: string
  updatedAt: string
  kind: RepeaterKind
  rxFreq: string
  txFreq: string
  offset: string
  toneText: string
  txTone?: string
  rxTone?: string
  mode?: string | null
  remark?: string
  source?: string
  sourceUser?: string
  sourceCreatedAt?: number | null
}

export interface RepeaterProvinceGroup {
  name: string
  code: number
  analog_total: number
  digi_total: number
  municipality?: boolean
}

export interface RepeaterRegionGroup {
  label: string
  children: RepeaterProvinceGroup[]
}

export interface RepeaterLibraryPackage {
  source: string
  fetchedAt: string
  total: number
  regions: RepeaterRegionGroup[]
  repeaters: RepeaterEntry[]
}

export const FALLBACK_REPEATER_LIBRARY: RepeaterEntry[] = [
  { id: 'sz-br7iat', region: '7 区', province: '广东省', provinceCode: 440000, city: '深圳', cityCode: 440300, area: '7区', name: '福田', callSign: 'BR7IAT', updatedAt: '2026/02/10', kind: '混合', rxFreq: '439.37500', txFreq: '434.37500', offset: '-5.0', toneText: 'TSQ88.5', txTone: '88.5', rxTone: '88.5', mode: 'C4FM' },
  { id: 'sz-br7jok', region: '7 区', province: '广东省', provinceCode: 440000, city: '深圳', cityCode: 440300, area: '7区', name: '梧桐山', callSign: 'BR7JOK', updatedAt: '2026/06/12', kind: '模拟', rxFreq: '439.46250', txFreq: '434.46250', offset: '-5.0', toneText: 'TSQ88.5', txTone: '88.5', rxTone: '88.5' },
  { id: 'gz-br7jdl', region: '7 区', province: '广东省', provinceCode: 440000, city: '广州', cityCode: 440100, area: '7区', name: '越秀', callSign: 'BR7JDL', updatedAt: '2026/04/06', kind: '混合', rxFreq: '439.05000', txFreq: '434.05000', offset: '-5.0', toneText: 'TSQ82.5', txTone: '82.5', rxTone: '82.5', mode: 'C4FM' },
]

let repeaterLibraryPromise: Promise<RepeaterLibraryPackage> | null = null

export function loadRepeaterLibrary() {
  repeaterLibraryPromise ??= fetch(`${import.meta.env.BASE_URL}data/hamcq-repeaters.json`, {
    headers: { Accept: 'application/json' },
  }).then(async (response) => {
    if (!response.ok) throw new Error(`中继台库加载失败：${response.status}`)
    return (await response.json()) as RepeaterLibraryPackage
  })
  return repeaterLibraryPromise
}

export function createFallbackRepeaterPackage(): RepeaterLibraryPackage {
  return {
    source: 'fallback',
    fetchedAt: new Date().toISOString(),
    total: FALLBACK_REPEATER_LIBRARY.length,
    regions: [
      {
        label: '7 区',
        children: [
          { name: '广东省', code: 440000, analog_total: FALLBACK_REPEATER_LIBRARY.length, digi_total: 0 },
        ],
      },
    ],
    repeaters: FALLBACK_REPEATER_LIBRARY,
  }
}

function formatFreq(value: number) {
  return value.toFixed(5)
}

function normalizeTone(value: string | null | undefined) {
  if (!value || value === 'OFF' || value === '0') return 'OFF'
  const trimmed = value.replace(/^TSQ/i, '').replace(/^T/i, '').trim()
  const numeric = Number(trimmed)
  if (!Number.isFinite(numeric)) return 'OFF'
  return numeric % 1 === 0 ? `${numeric.toFixed(1)}` : String(numeric)
}

export function buildChannelFromRepeater(entry: RepeaterEntry, id: number): Channel {
  const rx = Number(entry.rxFreq)
  const offset = Number(entry.offset)
  const tx = entry.txFreq || (Number.isFinite(rx) && Number.isFinite(offset) ? formatFreq(rx + offset) : entry.rxFreq)
  const name = `${entry.name}${entry.callSign ? entry.callSign.replace(/^BR/, '') : ''}`.slice(0, 12)
  const explicitRxTone = normalizeTone(entry.rxTone)
  const explicitTxTone = normalizeTone(entry.txTone)
  const fallbackTone = normalizeTone(entry.toneText)
  const usesTsq = entry.toneText.toUpperCase().includes('TSQ')

  return {
    id,
    visible: true,
    name,
    rxFreq: entry.rxFreq,
    txFreq: tx,
    rxTone: explicitRxTone !== 'OFF' ? explicitRxTone : (usesTsq ? fallbackTone : 'OFF'),
    txTone: explicitTxTone !== 'OFF' ? explicitTxTone : fallbackTone,
    txPower: 0,
    bandwidth: 0,
    scanAdd: 1,
    busyLock: 1,
    pttid: 0,
    signalGroup: 0,
  }
}

export function describeRepeater(entry: RepeaterEntry) {
  const tx = entry.txFreq ? ` -> ${entry.txFreq}` : ''
  const offset = entry.offset ? ` / ${entry.offset}` : ''
  const tone = entry.toneText ? ` / ${entry.toneText}` : ''
  const mode = entry.mode && entry.mode !== '0' ? ` / ${entry.mode}` : ''
  return `${entry.rxFreq}${tx}${offset}${tone}${mode}`
}
