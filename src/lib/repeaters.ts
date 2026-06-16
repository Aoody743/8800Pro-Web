import type { Channel } from '../core/models/radio'

export type RepeaterKind = '模拟' | '混合' | '数字'

export interface RepeaterEntry {
  id: string
  city: '深圳' | '广州'
  area: string
  name: string
  callSign?: string
  updatedAt: string
  kind: RepeaterKind
  rxFreq: string
  offset: string
  toneText: string
  mode?: string
}

export const REPEATER_LIBRARY: RepeaterEntry[] = [
  { id: 'sz-br7iat', city: '深圳', area: '7区', name: '福田', callSign: 'BR7IAT', updatedAt: '2026/02/10', kind: '混合', rxFreq: '439.37500', offset: '-5.0', toneText: 'TSQ88.5', mode: 'C4FM' },
  { id: 'sz-br7jok', city: '深圳', area: '7区', name: '梧桐山', callSign: 'BR7JOK', updatedAt: '2026/06/12', kind: '模拟', rxFreq: '439.46250', offset: '-5.0', toneText: 'TSQ88.5' },
  { id: 'sz-br7lzl', city: '深圳', area: '7区', name: '南山', callSign: 'BR7LZL', updatedAt: '2026/02/09', kind: '混合', rxFreq: '439.35000', offset: '-5.0', toneText: 'TSQ77', mode: 'C4FM' },
  { id: 'sz-wts-v', city: '深圳', area: '7区', name: '梧桐山V段', updatedAt: '2026/01/30', kind: '模拟', rxFreq: '145.30000', offset: '-0.6', toneText: 'T88.5' },
  { id: 'gz-br7jcc', city: '广州', area: '7区', name: '海珠金沙', callSign: 'BR7JCC', updatedAt: '2026/01/04', kind: '模拟', rxFreq: '439.32500', offset: '-5.0', toneText: 'T107.2' },
  { id: 'gz-br7jdl', city: '广州', area: '7区', name: '越秀', callSign: 'BR7JDL', updatedAt: '2026/04/06', kind: '混合', rxFreq: '439.05000', offset: '-5.0', toneText: 'TSQ82.5' },
  { id: 'gz-br7jda', city: '广州', area: '7区', name: '越秀', callSign: 'BR7JDA', updatedAt: '2026/01/04', kind: '模拟', rxFreq: '439.10000', offset: '-5.0', toneText: 'T110.9', mode: 'C4FM' },
  { id: 'gz-br7lbe', city: '广州', area: '7区', name: '天河中继', callSign: 'BR7LBE', updatedAt: '2026/01/30', kind: '模拟', rxFreq: '439.42500', offset: '-5.0', toneText: 'TSQ91.5' },
  { id: 'gz-br7jhd', city: '广州', area: '7区', name: '天河中继二台', callSign: 'BR7JHD', updatedAt: '2026/01/30', kind: '混合', rxFreq: '439.45000', offset: '-5.0', toneText: 'T136.5', mode: 'C4FM' },
  { id: 'gz-th-v', city: '广州', area: '7区', name: '天河中继', updatedAt: '2026/01/30', kind: '模拟', rxFreq: '145.36000', offset: '-0.6', toneText: 'TSQ91.5' },
]

function formatFreq(value: number) {
  return value.toFixed(5)
}

function normalizeTone(value: string) {
  const trimmed = value.replace(/^TSQ/i, '').replace(/^T/i, '')
  const numeric = Number(trimmed)
  if (!Number.isFinite(numeric)) return 'OFF'
  return numeric % 1 === 0 ? `${numeric.toFixed(1)}` : String(numeric)
}

export function buildChannelFromRepeater(entry: RepeaterEntry, id: number): Channel {
  const rx = Number(entry.rxFreq)
  const offset = Number(entry.offset)
  const tone = normalizeTone(entry.toneText)
  const name = `${entry.name}${entry.callSign ? entry.callSign.replace(/^BR/, '') : ''}`.slice(0, 12)
  const tx = Number.isFinite(rx) && Number.isFinite(offset) ? formatFreq(rx + offset) : entry.rxFreq
  const usesTsq = entry.toneText.toUpperCase().startsWith('TSQ')

  return {
    id,
    visible: true,
    name,
    rxFreq: entry.rxFreq,
    txFreq: tx,
    rxTone: usesTsq ? tone : 'OFF',
    txTone: tone,
    txPower: 0,
    bandwidth: 0,
    scanAdd: 0,
    busyLock: 1,
    pttid: 0,
    signalGroup: 0,
  }
}

export function describeRepeater(entry: RepeaterEntry) {
  return `${entry.rxFreq}/${entry.offset}/${entry.toneText}${entry.mode ? `/${entry.mode}` : ''}`
}
