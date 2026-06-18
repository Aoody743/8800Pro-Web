import Foundation

// MARK: - Protocol constants
public let ACK: UInt8 = 0x06

public func asciiBytes(_ value: String) -> Data { return Data(value.utf8) }

public func buildFrame(command: UInt8, address: UInt16, payload: Data, length: Int = 64) -> Data {
    var frame = Data(count: 68)
    frame[0] = command
    frame[1] = UInt8((address >> 8) & 0xFF)
    frame[2] = UInt8(address & 0xFF)
    frame[3] = UInt8(length)
    let slice = payload.prefix(length)
    frame.replaceSubrange(4..<(4+slice.count), with: slice)
    if slice.count < length {
        let padding = Data(repeating: 0xFF, count: length - slice.count)
        frame.replaceSubrange(4+slice.count..<(4+length), with: padding)
    }
    return frame
}

public func buildReadFrame(address: UInt16) -> Data { return Data([0x52, UInt8((address >> 8) & 0xFF), UInt8(address & 0xFF), 0x40]) }

public func buildWriteFrame(address: UInt16, payload: Data) -> Data { return buildFrame(command: 0x57, address: address, payload: payload, length: 64) }
