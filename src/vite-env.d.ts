/// <reference types="vite/client" />

interface SerialOptions {
  baudRate: number
  dataBits?: number
  stopBits?: number
  parity?: 'none' | 'even' | 'odd'
  bufferSize?: number
}

interface SerialPort {
  readonly readable?: ReadableStream<Uint8Array>
  readonly writable?: WritableStream<Uint8Array>
  open(options: SerialOptions): Promise<void>
  close(): Promise<void>
  setSignals?(signals: { dataTerminalReady?: boolean; requestToSend?: boolean }): Promise<void>
}

interface Navigator {
  serial: {
    requestPort(): Promise<SerialPort>
  }
  bluetooth: {
    requestDevice(options: {
      filters?: Array<{ name?: string; services?: string[] }>
      optionalServices?: string[]
    }): Promise<BluetoothDevice>
  }
}

interface BluetoothDevice {
  readonly name?: string
  readonly gatt?: BluetoothRemoteGATTServer
}

interface BluetoothRemoteGATTServer {
  connect(): Promise<BluetoothRemoteGATTServer>
  getPrimaryService(service: string): Promise<BluetoothRemoteGATTService>
  disconnect(): void
}

interface BluetoothRemoteGATTService {
  getCharacteristic(characteristic: string): Promise<BluetoothRemoteGATTCharacteristic>
}

interface BluetoothRemoteGATTCharacteristic extends EventTarget {
  readonly value?: DataView
  startNotifications(): Promise<BluetoothRemoteGATTCharacteristic>
  stopNotifications(): Promise<BluetoothRemoteGATTCharacteristic>
  writeValue(value: BufferSource): Promise<void>
  writeValueWithResponse?(value: BufferSource): Promise<void>
  writeValueWithoutResponse?(value: BufferSource): Promise<void>
}
