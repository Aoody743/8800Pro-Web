import { CHANNEL_CHOICES } from '../core/constants/choices'
import type { AppData, Channel } from '../core/models/radio'
import { cloneAppData, createDefaultAppData } from '../core/models/radio'

export function downloadJson(data: AppData) {
  downloadBlob(JSON.stringify(data, null, 2), `Backup-shx8800pro-${timestamp()}.json`, 'application/json')
}

export function loadJsonFile(file: File) {
  return file.text().then((text) => JSON.parse(text) as AppData)
}

export async function exportExcel(data: AppData) {
  const XLSX = await import('xlsx')
  const workbook = XLSX.utils.book_new()
  data.channels.forEach((bank, bankIndex) => {
    const rows = bank.map((channel) => ({
      信道: channel.id,
      接收频率: channel.rxFreq,
      接收亚音: channel.rxTone,
      发射频率: channel.txFreq,
      发射亚音: channel.txTone,
      功率: CHANNEL_CHOICES.power[channel.txPower] ?? CHANNEL_CHOICES.power[0],
      带宽: CHANNEL_CHOICES.bandwidth[channel.bandwidth] ?? CHANNEL_CHOICES.bandwidth[0],
      扫描加入: CHANNEL_CHOICES.scanAdd[channel.scanAdd] ?? CHANNEL_CHOICES.scanAdd[0],
      繁忙锁: CHANNEL_CHOICES.busyLock[channel.busyLock] ?? CHANNEL_CHOICES.busyLock[0],
      'PTT-ID': CHANNEL_CHOICES.pttid[channel.pttid] ?? CHANNEL_CHOICES.pttid[0],
      信令组: CHANNEL_CHOICES.signalGroup[channel.signalGroup] ?? CHANNEL_CHOICES.signalGroup[0],
      信道名称: channel.name,
    }))
    const sheet = XLSX.utils.json_to_sheet(rows)
    XLSX.utils.book_append_sheet(workbook, sheet, data.bankNames[bankIndex] || `区域${bankIndex + 1}`)
  })
  XLSX.writeFile(workbook, `Channels-${timestamp()}.xlsx`)
}

export async function importExcel(file: File, base: AppData) {
  const XLSX = await import('xlsx')
  const arrayBuffer = await file.arrayBuffer()
  const workbook = XLSX.read(arrayBuffer)
  const next = cloneAppData(base)
  workbook.SheetNames.slice(0, 8).forEach((sheetName, bankIndex) => {
    next.bankNames[bankIndex] = sheetName
    const rows = XLSX.utils.sheet_to_json<Record<string, unknown>>(workbook.Sheets[sheetName])
    next.channels[bankIndex] = Array.from({ length: 64 }, (_, index) =>
      excelRowToChannel(rows[index], index + 1),
    )
  })
  next.updatedAt = new Date().toISOString()
  return next
}

export function exportCsv(data: AppData) {
  const rows = data.channels.flatMap((bank, bankIndex) =>
    bank.map((channel) => ({
      区域: data.bankNames[bankIndex],
      信道: channel.id,
      接收频率: channel.rxFreq,
      接收亚音: channel.rxTone,
      发射频率: channel.txFreq,
      发射亚音: channel.txTone,
      功率: CHANNEL_CHOICES.power[channel.txPower] ?? CHANNEL_CHOICES.power[0],
      带宽: CHANNEL_CHOICES.bandwidth[channel.bandwidth] ?? CHANNEL_CHOICES.bandwidth[0],
      扫描加入: CHANNEL_CHOICES.scanAdd[channel.scanAdd] ?? CHANNEL_CHOICES.scanAdd[0],
      繁忙锁: CHANNEL_CHOICES.busyLock[channel.busyLock] ?? CHANNEL_CHOICES.busyLock[0],
      'PTT-ID': CHANNEL_CHOICES.pttid[channel.pttid] ?? CHANNEL_CHOICES.pttid[0],
      信令组: CHANNEL_CHOICES.signalGroup[channel.signalGroup] ?? CHANNEL_CHOICES.signalGroup[0],
      信道名称: channel.name,
    })),
  )
  const headers = Object.keys(rows[0] ?? { 区域: '', 信道: '', 接收频率: '', 接收亚音: '', 发射频率: '', 发射亚音: '', 功率: '', 带宽: '', 扫描加入: '', 繁忙锁: '', 'PTT-ID': '', 信令组: '', 信道名称: '' })
  const csv = [headers.join(','), ...rows.map((row) => headers.map((header) => csvCell(row[header as keyof typeof row])).join(','))].join('\n')
  downloadBlob(csv, `Channels-${timestamp()}.csv`, 'text/csv;charset=utf-8')
}

function csvCell(value: unknown) {
  const text = String(value ?? '')
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text
}

function excelRowToChannel(row: Record<string, unknown> | undefined, id: number): Channel {
  if (!row) return createDefaultAppData().channels[0][id - 1]
  const rxFreq = String(row['接收频率'] ?? '')
  return {
    id,
    rxFreq,
    rxTone: String(row['接收亚音'] ?? 'OFF') || 'OFF',
    txFreq: String(row['发射频率'] ?? ''),
    txTone: String(row['发射亚音'] ?? 'OFF') || 'OFF',
    txPower: indexOrZero(CHANNEL_CHOICES.power, row['功率']),
    bandwidth: indexOrZero(CHANNEL_CHOICES.bandwidth, row['带宽']),
    scanAdd: indexOrZero(CHANNEL_CHOICES.scanAdd, row['扫描加入']),
    busyLock: indexOrZero(CHANNEL_CHOICES.busyLock, row['繁忙锁']),
    pttid: indexOrZero(CHANNEL_CHOICES.pttid, row['PTT-ID']),
    signalGroup: indexOrZero(CHANNEL_CHOICES.signalGroup, row['信令组']),
    name: String(row['信道名称'] ?? ''),
    visible: Boolean(rxFreq),
  }
}

function indexOrZero<T extends readonly string[]>(options: T, value: unknown) {
  const index = options.indexOf(String(value) as T[number])
  return index >= 0 ? index : 0
}

function downloadBlob(content: BlobPart, filename: string, type: string) {
  const blob = new Blob([content], { type })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  URL.revokeObjectURL(url)
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '-')
}
