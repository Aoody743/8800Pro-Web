import Foundation

public struct SHX8800PRO {
    public static let minFreqMhz: Double = 100
    public static let maxFreqMhz: Double = 520
    public static let channelBanks = 8
    public static let channelsPerBank = 64
    public static let channelBytes = 32
    public static let framePayloadBytes = 64
    public static let frameBytes = 68
    public static let vfoAddress: UInt16 = 0x8000
    public static let functionAddress: UInt16 = 0x9000
    public static let dtmfStartAddress: UInt16 = 0xa000
    public static let bankNameAAddress: UInt16 = 0xa200
    public static let bankNameBAddress: UInt16 = 0xa240
    public static let fmAddress: UInt16 = 0xb000
    public static let bootLogoAddress: UInt16 = 0x7400
    public static let bootImageWidth = 128
    public static let bootImageHeight = 128
    public static let bootImageBytes = bootImageWidth * bootImageHeight * 2
    public static let serialBaudRate = 115200
    public static let bluetoothName = "walkie-talkie"
    public static let bluetoothService = "0000FFE0-0000-1000-8000-00805F9B34FB"
    public static let bluetoothCharacteristic = "0000FFE1-0000-1000-8000-00805F9B34FB"
}
