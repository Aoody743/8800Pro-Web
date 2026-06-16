import assert from 'node:assert/strict'
import { applyBlockToAppData, encodeBlockForAddress } from '../src/core/codec/shx8800pro-codec'
import { encodeChannelFrequency, decodeChannelFrequency, encodeVfoFrequency, decodeVfoFrequency } from '../src/core/codec/frequency'
import { encodeRadioText, decodeRadioText } from '../src/core/codec/text'
import { encodeTone, decodeTone } from '../src/core/codec/tone'
import { getShx8800ProReadWriteAddresses, SHX8800PRO } from '../src/core/constants/memory-map'
import { cloneAppData, createDefaultAppData } from '../src/core/models/radio'
import { buildFrame, buildReadFrame, buildWriteFrame } from '../src/core/protocol/frame'
import { buildBootImagePackage, crc16Ccitt, Shx8800ProSession } from '../src/core/protocol/shx8800pro-session'
import type { RadioTransport } from '../src/transport/transport'

function roundtripAddress(address: number) {
  const source = createDefaultAppData()
  source.channels[0][0] = {
    ...source.channels[0][0],
    visible: true,
    rxFreq: '145.50000',
    txFreq: '435.50000',
    rxTone: '67.0',
    txTone: 'D023N',
    txPower: 2,
    bandwidth: 1,
    scanAdd: 1,
    busyLock: 1,
    pttid: 2,
    signalGroup: 5,
    name: '测试01',
  }
  source.channels[0][1] = {
    ...source.channels[0][1],
    visible: true,
    rxFreq: '440.62500',
    txFreq: '440.62500',
    rxTone: 'OFF',
    txTone: 'OFF',
    name: 'SAT-A',
  }
  const payload = encodeBlockForAddress(source, address)
  const target = cloneAppData(createDefaultAppData())
  applyBlockToAppData(target, address, payload)
  return { source, target, payload }
}

assert.deepEqual(Array.from(encodeChannelFrequency('145.50000')), [0x00, 0x00, 0x55, 0x14])
assert.equal(decodeChannelFrequency(encodeChannelFrequency('440.62500'), 0), '440.62500')
assert.equal(decodeVfoFrequency(encodeVfoFrequency('145.50000')), '145.50000')

assert.deepEqual(Array.from(encodeTone('OFF')), [0, 0])
assert.equal(decodeTone(encodeTone('67.0'), 0), '67.0')
assert.equal(decodeTone(encodeTone('D023N'), 0), 'D023N')

const text = encodeRadioText('区域一ABC', 12)
assert.equal(decodeRadioText(text, 0, 12), '区域一ABC')
assert.equal(decodeRadioText(encodeRadioText('区域一二三四五六', 5), 0, 5), '区域')

const channelRoundtrip = roundtripAddress(0)
assert.equal(channelRoundtrip.target.channels[0][0].rxFreq, '145.50000')
assert.equal(channelRoundtrip.target.channels[0][0].txFreq, '435.50000')
assert.equal(channelRoundtrip.target.channels[0][0].rxTone, '67.0')
assert.equal(channelRoundtrip.target.channels[0][0].txTone, 'D023N')
assert.equal(channelRoundtrip.target.channels[0][0].name, '测试01')
assert.equal(channelRoundtrip.target.channels[0][1].rxFreq, '440.62500')

const vfoSource = createDefaultAppData()
vfoSource.vfos.vfoAFreq = '145.50000'
vfoSource.vfos.vfoBFreq = '440.62500'
const vfoTarget = createDefaultAppData()
applyBlockToAppData(vfoTarget, SHX8800PRO.vfoAddress, encodeBlockForAddress(vfoSource, SHX8800PRO.vfoAddress))
assert.equal(vfoTarget.vfos.vfoAFreq, '145.50000')
assert.equal(vfoTarget.vfos.vfoBFreq, '440.62500')

const functionTarget = createDefaultAppData()
const functionSource = createDefaultAppData()
functionSource.functions.callSign = 'N0CALL'
functionSource.functions.bluetoothAudioGain = 4
applyBlockToAppData(functionTarget, SHX8800PRO.functionAddress, encodeBlockForAddress(functionSource, SHX8800PRO.functionAddress))
assert.equal(functionTarget.functions.callSign, 'N0CALL')
assert.equal(functionTarget.functions.bluetoothAudioGain, 4)

assert.deepEqual(Array.from(buildReadFrame(0x9000)), [0x52, 0x90, 0x00, 0x40])
const writeFrame = buildWriteFrame(0x9000, new Uint8Array(64).fill(0xaa))
assert.equal(writeFrame.length, 68)
assert.equal(writeFrame[0], 0x57)
assert.equal(writeFrame[3], 0x40)

const bootPacket = buildBootImagePackage(0x02, 0, new TextEncoder().encode('PROGRAM'))
assert.equal(bootPacket[0], 0xa5)
assert.equal(bootPacket[1], 0x02)
assert.equal((bootPacket[4] << 8) | bootPacket[5], 7)
assert.equal((bootPacket.at(-2)! << 8) | bootPacket.at(-1)!, crc16Ccitt(bootPacket, 1, bootPacket.length - 3))

class NoisyReadTransport implements RadioTransport {
  readonly kind = 'serial' as const
  readonly label = 'test'
  private queue: number[] = [0x00, 0xff, 0x06, ...Array.from(new Uint8Array([0x01, 0x36, 0x01, 0x74, 0x04, 0x00, 0x05, 0x20, 0x02, 0x00, 0x02, 0x60, 0x00, 0x03, 0x50, 0x04]))]

  constructor(private readonly source = createDefaultAppData()) {
    this.source.bankNames[1] = '中继台'
    this.source.channels[1][0] = {
      ...this.source.channels[1][0],
      visible: true,
      rxFreq: '439.46250',
      txFreq: '434.46250',
      rxTone: '88.5',
      txTone: '88.5',
      txPower: 0,
      bandwidth: 1,
      scanAdd: 1,
      name: '深圳梧桐山',
    }
    this.source.functions.currentBankA = 1
  }

  async open() {}
  async close() {}
  drain() {}

  async write(data: Uint8Array) {
    if (data[0] !== 0x52) return
    const address = (data[1] << 8) | data[2]
    const frame = buildFrame(0x52, address, encodeBlockForAddress(this.source, address))
    this.queue.push(0x00, 0xff, ...Array.from(frame))
  }

  async read(length: number, timeoutMs = 1000) {
    const started = Date.now()
    while (this.queue.length < length) {
      if (Date.now() - started > timeoutMs) throw new Error('timeout')
      await new Promise((resolve) => setTimeout(resolve, 1))
    }
    return new Uint8Array(this.queue.splice(0, length))
  }
}

const noisyRead = await new Shx8800ProSession(new NoisyReadTransport()).readRadio()
assert.equal(noisyRead.bankNames[1], '中继台')
assert.equal(noisyRead.functions.currentBankA, 1)
assert.equal(noisyRead.channels[1][0].rxFreq, '439.46250')
assert.equal(noisyRead.channels[1][0].name, '深圳梧桐山')
assert.equal(getShx8800ProReadWriteAddresses().includes(0x0800), true)

const rawPreserveData = createDefaultAppData()
const rawFunction = new Uint8Array(64)
rawFunction[0] = 3
rawFunction[8] = 1
rawFunction[35] = 1
applyBlockToAppData(rawPreserveData, 0x9000, rawFunction)
assert.deepEqual(Array.from(encodeBlockForAddress(rawPreserveData, 0x9000)), Array.from(rawFunction))

const rawBankNames = new Uint8Array(64).fill(0xff)
rawBankNames.set(encodeRadioText('中继台', 12), 16)
applyBlockToAppData(rawPreserveData, 0xa200, rawBankNames)
assert.equal(rawPreserveData.bankNames[0], '')
assert.equal(rawPreserveData.bankNames[1], '中继台')
assert.deepEqual(Array.from(encodeBlockForAddress(rawPreserveData, 0xa200)), Array.from(rawBankNames))

console.log('protocol tests passed')
