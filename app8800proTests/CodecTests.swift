import XCTest
@testable import app8800pro

final class CodecTests: XCTestCase {
    func testEncodeBlockLength() {
        let payload = Codec.encodeBlock(for: RadioAppData.default, address: 0x0000)
        XCTAssertEqual(payload.count, SHX8800PRO.framePayloadBytes)
    }

    func testApplyBlockStoresRawPayload() {
        var data = RadioAppData.default
        let sample = Data(repeating: 0x12, count: SHX8800PRO.framePayloadBytes)

        Codec.applyBlock(to: &data, address: 0x1240, frame: sample)

        XCTAssertEqual(data.rawBlocks?["1240"], Array(sample))
    }

    func testBleHeaderPollutionDoesNotBecomeChannel() {
        var data = RadioAppData.default
        var payload = Data(repeating: 0xFF, count: SHX8800PRO.framePayloadBytes)
        payload.replaceSubrange(0..<4, with: Data([0x57, 0x00, 0x00, 0x40]))

        Codec.applyBlock(to: &data, address: 0x0000, frame: payload)

        XCTAssertTrue(data.channels[0][0].rxFreq.isEmpty)
        XCTAssertFalse(data.channels[0][0].visible)
    }

    func testBluetoothEmptyMateBlockSanitizesPollution() {
        var data = RadioAppData.default
        data.channels[0][1].rxFreq = "145.62500"
        data.channels[0][1].txFreq = "145.62500"
        data.channels[0][1].visible = true
        var pollutedRaw = Data([0x57, 0x00, 0x00, 0x40])
        pollutedRaw.append(Data(repeating: 0xFF, count: 60))
        data.rawBlocks = [
            "0000": Array(pollutedRaw)
        ]

        let payload = Codec.encodeBluetoothChannelBlock(for: data, address: 0x0000, includeEmpty: true)

        XCTAssertEqual(payload?.prefix(32), Data(repeating: 0xFF, count: 32))
        XCTAssertNotEqual(payload?.suffix(32), Data(repeating: 0xFF, count: 32))
    }
}
