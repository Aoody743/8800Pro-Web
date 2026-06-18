import { readFileSync, writeFileSync } from 'node:fs'
import { applyBlockToAppData, getBluetoothWriteBlocks } from '../src/core/codec/shx8800pro-codec'
import { createDefaultAppData } from '../src/core/models/radio'

interface DumpFrame {
  address: number
  payload: number[]
}

interface DumpFile {
  frames: DumpFrame[]
}

const input = process.argv[2]
const output = process.argv[3]

if (!input || !output) {
  console.error('usage: tsx tools/build-ble-write-plan.ts <dump.json> <plan.json>')
  process.exit(2)
}

const dump = JSON.parse(readFileSync(input, 'utf8')) as DumpFile
const data = createDefaultAppData()

for (const frame of dump.frames) {
  applyBlockToAppData(data, frame.address, Uint8Array.from(frame.payload))
}

const suspicious = data.channels
  .flat()
  .filter((channel) => /^4(?:04|08|12)\.0\d{4}57$/.test(channel.rxFreq))

const blocks = getBluetoothWriteBlocks(data)
writeFileSync(
  output,
  `${JSON.stringify(
    {
      generatedAt: new Date().toISOString(),
      source: input,
      visibleChannels: data.channels.flat().filter((channel) => channel.visible && channel.rxFreq).length,
      suspiciousChannels: suspicious.map((channel) => ({ id: channel.id, rxFreq: channel.rxFreq, name: channel.name })),
      frames: blocks.map((block) => ({
        address: block.address,
        payload: Array.from(block.payload),
      })),
    },
    null,
    2,
  )}\n`,
)

console.log(`read ${dump.frames.length} blocks`)
console.log(`write plan ${blocks.length} blocks`)
console.log(`visible channels ${data.channels.flat().filter((channel) => channel.visible && channel.rxFreq).length}`)
console.log(`suspicious channels ${suspicious.length}`)
