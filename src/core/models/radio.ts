import { SHX8800PRO } from '../constants/memory-map'

export interface Channel {
  id: number
  rxFreq: string
  rxTone: string
  txFreq: string
  txTone: string
  txPower: number
  bandwidth: number
  scanAdd: number
  busyLock: number
  pttid: number
  signalGroup: number
  name: string
  visible: boolean
}

export interface VfoInfos {
  pttid: number
  vfoAFreq: string
  vfoBFreq: string
  vfoAOffset: string
  vfoBOffset: string
  vfoARxTone: string
  vfoATxTone: string
  vfoBRxTone: string
  vfoBTxTone: string
  vfoATxPower: number
  vfoBTxPower: number
  vfoABandwidth: number
  vfoBBandwidth: number
  vfoAStep: number
  vfoBStep: number
  vfoABusyLock: number
  vfoBBusyLock: number
  vfoASignalGroup: number
  vfoBSignalGroup: number
  vfoADirection: number
  vfoBDirection: number
  vfoAScramble: number
  vfoBScramble: number
}

export interface FunctionSettings {
  sql: number
  saveMode: number
  vox: number
  backlight: number
  dualStandby: number
  tot: number
  beep: number
  voice: number
  sideTone: number
  scanMode: number
  pttDelay: number
  chADisplay: number
  chBDisplay: number
  autoLock: number
  alarmMode: number
  localSosTone: number
  tailClear: number
  rptTailClear: number
  rptTailDetect: number
  roger: number
  fmEnable: number
  chAWorkmode: number
  chBWorkmode: number
  keyLock: number
  powerOnDisplay: number
  tone: number
  voxDelay: number
  menuQuitTime: number
  micGain: number
  powerOnDelay: number
  voxSwitch: number
  key2Short: number
  key2Long: number
  currentBankA: number
  currentBankB: number
  bluetoothAudioGain: number
  bluetoothMicGain: number
  callSign: string
}

export interface DtmfSettings {
  localId: string
  pttid: number
  wordTime: number
  idleTime: number
  groups: string[]
  groupNames: string[]
}

export interface FmSettings {
  currentFreq: number
  channels: number[]
}

export interface BootImageDraft {
  name: string
  width: number
  height: number
  dataUrl?: string
  rgb565?: number[]
}

export interface AppData {
  model: 'SHX8800PRO'
  bankNames: string[]
  channels: Channel[][]
  vfos: VfoInfos
  functions: FunctionSettings
  dtmf: DtmfSettings
  fm: FmSettings
  rawBlocks?: Record<string, number[]>
  bootImage?: BootImageDraft
  updatedAt: string
}

export function createEmptyChannel(id: number): Channel {
  return {
    id,
    rxFreq: '',
    rxTone: 'OFF',
    txFreq: '',
    txTone: 'OFF',
    txPower: 0,
    bandwidth: 0,
    scanAdd: 0,
    busyLock: 0,
    pttid: 0,
    signalGroup: 0,
    name: '',
    visible: false,
  }
}

export function createDefaultAppData(): AppData {
  return {
    model: 'SHX8800PRO',
    bankNames: ['区域一', '区域二', '区域三', '区域四', '区域五', '区域六', '区域七', '区域八'],
    channels: Array.from({ length: SHX8800PRO.channelBanks }, () =>
      Array.from({ length: SHX8800PRO.channelsPerBank }, (_, index) => createEmptyChannel(index + 1)),
    ),
    vfos: {
      pttid: 0,
      vfoAFreq: '440.62500',
      vfoBFreq: '145.62500',
      vfoAOffset: '00.0000',
      vfoBOffset: '00.0000',
      vfoARxTone: 'OFF',
      vfoATxTone: 'OFF',
      vfoBRxTone: 'OFF',
      vfoBTxTone: 'OFF',
      vfoATxPower: 0,
      vfoBTxPower: 0,
      vfoABandwidth: 0,
      vfoBBandwidth: 0,
      vfoAStep: 0,
      vfoBStep: 0,
      vfoABusyLock: 0,
      vfoBBusyLock: 0,
      vfoASignalGroup: 0,
      vfoBSignalGroup: 0,
      vfoADirection: 0,
      vfoBDirection: 0,
      vfoAScramble: 0,
      vfoBScramble: 0,
    },
    functions: {
      sql: 3,
      saveMode: 1,
      vox: 1,
      backlight: 5,
      dualStandby: 0,
      tot: 2,
      beep: 1,
      voice: 1,
      sideTone: 0,
      scanMode: 1,
      pttDelay: 4,
      chADisplay: 0,
      chBDisplay: 0,
      autoLock: 2,
      alarmMode: 0,
      localSosTone: 1,
      tailClear: 1,
      rptTailClear: 5,
      rptTailDetect: 5,
      roger: 0,
      fmEnable: 0,
      chAWorkmode: 0,
      chBWorkmode: 0,
      keyLock: 0,
      powerOnDisplay: 0,
      tone: 2,
      voxDelay: 5,
      menuQuitTime: 1,
      micGain: 1,
      powerOnDelay: 0,
      voxSwitch: 0,
      key2Short: 0,
      key2Long: 1,
      currentBankA: 0,
      currentBankB: 0,
      bluetoothAudioGain: 2,
      bluetoothMicGain: 2,
      callSign: '',
    },
    dtmf: {
      localId: '100',
      pttid: 0,
      wordTime: 1,
      idleTime: 1,
      groups: Array.from({ length: 15 }, (_, index) => String(101 + index)),
      groupNames: Array.from({ length: 15 }, (_, index) => `成员${index + 1}`),
    },
    fm: {
      currentFreq: 904,
      channels: Array.from({ length: 30 }, () => 0),
    },
    updatedAt: new Date().toISOString(),
  }
}

export function cloneAppData(data: AppData): AppData {
  return JSON.parse(JSON.stringify(data)) as AppData
}

export function countVisibleChannels(data: AppData) {
  return data.channels.flat().filter((channel) => channel.visible && channel.rxFreq).length
}
