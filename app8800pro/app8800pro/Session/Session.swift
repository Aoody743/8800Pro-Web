import Foundation

/// Session implementation that mirrors the web protocol
public class Shx8800ProSession {
    private let bluetooth: BluetoothManager
    private var onLog: ((String) -> Void)?
    private var onProgress: ((String, Double) -> Void)?
    private var receiveBuffer = Data()
    private var pendingMatcher: ((inout Data) -> Data?)?
    private var pendingResponse: ((Data?) -> Void)?
    private var pendingReadToken = 0

    private struct BluetoothWriteBlock {
        var address: UInt16
        var payload: Data
    }
    
    public init(bluetooth: BluetoothManager) {
        self.bluetooth = bluetooth
        
        // Listen for incoming data
        bluetooth.onReceive = { [weak self] data in
            self?.handleReceived(data)
        }
    }
    
    public func setLogHandler(_ handler: @escaping (String) -> Void) {
        self.onLog = handler
    }
    
    public func setProgressHandler(_ handler: @escaping (String, Double) -> Void) {
        self.onProgress = handler
    }
    
    // MARK: - Public API
    
    public func readRadio(completion: @escaping (RadioAppData?, Error?) -> Void) {
        log("开始读频流程")
        
        performHandshake { [weak self] error in
            guard let self = self, error == nil else {
                completion(nil, error)
                return
            }
            
            self.log("握手成功，开始读取配置")
            self.readAllBlocks { data, error in
                if let error = error {
                    completion(nil, error)
                } else if var data = data {
                    data.updatedAt = Date()
                    completion(data, nil)
                } else {
                    completion(nil, NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "读取失败"]))
                }
            }
        }
    }
    
    public func writeRadio(data: RadioAppData, completion: @escaping (Error?) -> Void) {
        log("开始写频流程")
        
        performHandshake { [weak self] error in
            guard let self = self, error == nil else {
                completion(error)
                return
            }
            
            self.log("握手成功，开始写入配置")
            self.writeAllBlocks(data: data, completion: completion)
        }
    }

    public func writeBootImage(_ rgb565: Data, completion: @escaping (Error?) -> Void) {
        guard rgb565.count == SHX8800PRO.bootImageBytes else {
            completion(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "开机图数据必须是 128×128 RGB565，也就是 \(SHX8800PRO.bootImageBytes) bytes"]))
            return
        }

        log("开始写入开机图")
        drainReceiveBuffer()
        writeBootImageSequence(rgb565: rgb565, completion: completion)
    }
    
    // MARK: - Handshake
    
    private func performHandshake(completion: @escaping (Error?) -> Void) {
        drainReceiveBuffer()
        log("发送握手命令: PROGRAMSHXPU")
        
        guard let data = "PROGRAMSHXPU".data(using: .ascii) else {
            completion(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "握手命令编码失败"]))
            return
        }

        sendBluetoothPacket(data) { [weak self] error in
            guard let self = self else {
                completion(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "会话已释放"]))
                return
            }

            if let error {
                completion(error)
                return
            }

            self.waitForAck(timeout: 5.0) { [weak self] response in
                guard let self = self else {
                    completion(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "会话已释放"]))
                    return
                }
                
                if let response = response, !response.isEmpty {
                    self.log("握手响应: \(response.sessionHexString)")
                    
                    self.sendBluetoothPacket(Data([0x46])) { error in
                        if let error {
                            completion(error)
                            return
                        }

                        self.waitForIdent(timeout: 5.0) { ident in
                            guard let ident else {
                                self.log("握手失败：未收到设备标识")
                                completion(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "握手失败：未收到设备标识"]))
                                return
                            }
                            self.log("设备标识: \(ident.sessionHexString)")
                            self.log("握手完成")
                            completion(nil)
                        }
                    }
                } else {
                    self.log("握手超时")
                    completion(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "握手超时，请检查设备连接"]))
                }
            }
        }
    }
    
    // MARK: - Read All Blocks
    
    private func readAllBlocks(completion: @escaping (RadioAppData?, Error?) -> Void) {
        var data = RadioAppData.default
        let addresses = generateReadAddresses()
        let total = addresses.count
        var current = 0
        
        func readNext() {
            guard current < addresses.count else {
                log("读频完成，共读取 \(total) 个数据块")
                onProgress?("读频完成", 1.0)
                bluetooth.send(Data([0x45]))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    completion(data, nil)
                }
                return
            }
            
            let address = addresses[current]
            current += 1
            
            let progress = Double(current) / Double(total)
            onProgress?("读取中 \(current)/\(total)", progress)
            
            readBlock(address: address) { [weak self] blockData, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.log("读取块 0x\(String(address, radix: 16)) 失败: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                if let blockData = blockData {
                    Codec.applyBlock(to: &data, address: address, frame: blockData)
                }
                
                // Continue with next block
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    readNext()
                }
            }
        }
        
        readNext()
    }
    
    // MARK: - Write All Blocks
    
    private func writeAllBlocks(data: RadioAppData, completion: @escaping (Error?) -> Void) {
        let pairs: [(BluetoothWriteBlock, BluetoothWriteBlock)]
        do {
            pairs = try groupBluetoothWritePairs(generateBluetoothWriteBlocks(data: data))
        } catch {
            completion(error)
            return
        }

        let total = pairs.count * 2
        var current = 0
        logBluetoothWritePlan(pairs)
        
        func writeNext() {
            guard current < pairs.count else {
                log("写频完成，共写入 \(total) 个蓝牙数据块")
                onProgress?("写频完成", 1.0)
                
                sendBluetoothPacket(Data([0x45])) { error in
                    if let error {
                        completion(error)
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        completion(nil)
                    }
                }
                return
            }
            
            let pair = pairs[current]
            let blockIndex = current * 2
            current += 1

            let progress = Double(blockIndex) / Double(max(total, 1))
            onProgress?("写入 \(addressLabel(pair.0.address))", progress)

            writeBluetoothPair(pair.0, pair.1, blockIndex: blockIndex, total: total) { error in
                if let error = error {
                    completion(error)
                    return
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    writeNext()
                }
            }
        }
        
        writeNext()
    }

    private func writeBluetoothPair(
        _ first: BluetoothWriteBlock,
        _ second: BluetoothWriteBlock,
        blockIndex: Int,
        total: Int,
        completion: @escaping (Error?) -> Void
    ) {
        if second.address == first.address + UInt16(SHX8800PRO.framePayloadBytes) {
            writeBluetoothStreamPair(first, second, blockIndex: blockIndex, total: total, completion: completion)
        } else {
            writeBluetoothConfigPair(first, second, blockIndex: blockIndex, total: total, completion: completion)
        }
    }

    private func writeBluetoothStreamPair(
        _ first: BluetoothWriteBlock,
        _ second: BluetoothWriteBlock,
        blockIndex: Int,
        total: Int,
        completion: @escaping (Error?) -> Void
    ) {
        let header = Data([0x57, UInt8((first.address >> 8) & 0xFF), UInt8(first.address & 0xFF), 0x40])
        log("TX BLE HEADER \(addressLabel(first.address)) \(header.sessionHexString)")

        sendBluetoothPacket(header) { [weak self] error in
            guard let self else { return }
            if let error {
                completion(error)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                self.log("TX BLE DATA \(self.addressLabel(first.address)) \(Data(first.payload.prefix(8)).sessionHexString) ...")
                self.sendBluetoothPacket(first.payload) { error in
                    if let error {
                        completion(error)
                        return
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        self.onProgress?("写入 \(self.addressLabel(second.address))", Double(blockIndex + 1) / Double(max(total, 1)))
                        self.log("TX BLE DATA \(self.addressLabel(second.address)) \(Data(second.payload.prefix(8)).sessionHexString) ...")
                        self.sendBluetoothPacket(second.payload) { error in
                            if let error {
                                completion(error)
                                return
                            }

                            self.waitForAck(timeout: 6.0) { response in
                                if response != nil {
                                    completion(nil)
                                } else {
                                    completion(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "蓝牙写入失败：\(self.addressLabel(first.address)) / \(self.addressLabel(second.address))"]))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func writeBluetoothConfigPair(
        _ first: BluetoothWriteBlock,
        _ second: BluetoothWriteBlock,
        blockIndex: Int,
        total: Int,
        completion: @escaping (Error?) -> Void
    ) {
        let firstFrame = buildWriteFrame(address: first.address, payload: first.payload)
        log("TX BLE WRITE \(addressLabel(first.address)) \(Data(firstFrame.prefix(8)).sessionHexString) ...")

        sendBluetoothPacket(firstFrame) { [weak self] error in
            guard let self else { return }
            if let error {
                completion(error)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                let secondFrame = buildWriteFrame(address: second.address, payload: second.payload)
                self.onProgress?("写入 \(self.addressLabel(second.address))", Double(blockIndex + 1) / Double(max(total, 1)))
                self.log("TX BLE WRITE \(self.addressLabel(second.address)) \(Data(secondFrame.prefix(8)).sessionHexString) ...")
                self.sendBluetoothPacket(secondFrame) { error in
                    if let error {
                        completion(error)
                        return
                    }

                    self.waitForAck(timeout: 6.0) { response in
                        if response != nil {
                            completion(nil)
                        } else {
                            completion(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "蓝牙写入失败：\(self.addressLabel(first.address)) / \(self.addressLabel(second.address))"]))
                        }
                    }
                }
            }
        }
    }

    private func sendBluetoothPacket(_ data: Data, completion: @escaping (Error?) -> Void) {
        bluetooth.send(data) { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    // MARK: - Single Block Operations
    
    private func readBlock(address: UInt16, completion: @escaping (Data?, Error?) -> Void) {
        let frame = buildReadFrame(address: address)
        log("TX READ \(addressLabel(address)) \(frame.sessionHexString)")
        receiveBuffer.removeAll()

        sendBluetoothPacket(frame) { [weak self] error in
            guard let self else { return }
            if let error {
                completion(nil, error)
                return
            }

            self.waitForFrame(address: address, timeout: 8.0) { response in
                if let response = response, response.count >= SHX8800PRO.frameBytes {
                    self.log("RX READ \(self.addressLabel(address)) \(Data(response.prefix(8)).sessionHexString) ...")
                    completion(response, nil)
                } else {
                    completion(nil, NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "读取超时或数据不完整：\(self.addressLabel(address))"]))
                }
            }
        }
    }
    
    private func writeBlock(address: UInt16, data: RadioAppData, completion: @escaping (Error?) -> Void) {
        let payload = Codec.encodeBlock(for: data, address: address)
        let frame = buildWriteFrame(address: address, payload: payload)

        func attempt(_ index: Int) {
            self.log("TX WRITE \(self.addressLabel(address)) \(Data(frame.prefix(8)).sessionHexString) ...")
            self.sendBluetoothPacket(frame) { [weak self] error in
                guard let self else { return }
                if let error {
                    completion(error)
                    return
                }

                self.waitForAck(timeout: 5.0) { response in
                    if let response = response, !response.isEmpty {
                        completion(nil)
                    } else if index < 4 {
                        self.log("写入块 \(self.addressLabel(address)) 未确认，重试 \(index + 2)/5")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            attempt(index + 1)
                        }
                    } else {
                        completion(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "写入失败：\(self.addressLabel(address))"]))
                    }
                }
            }
        }

        attempt(0)
    }
    
    // MARK: - Helpers
    
    private func generateReadAddresses() -> [UInt16] {
        var addresses: [UInt16] = []
        
        // Channels: 0x0000 - 0x3FFF (256 blocks, each holds 2 channels)
        for i in 0..<256 {
            addresses.append(UInt16(i * 64))
        }
        
        addresses.append(SHX8800PRO.vfoAddress)

        addresses.append(SHX8800PRO.functionAddress)

        for address in stride(from: SHX8800PRO.dtmfStartAddress, through: SHX8800PRO.dtmfStartAddress + 0x100, by: 64) {
            addresses.append(address)
        }

        addresses.append(SHX8800PRO.bankNameAAddress)
        addresses.append(SHX8800PRO.bankNameBAddress)
        addresses.append(SHX8800PRO.fmAddress)
        
        return addresses
    }
    
    private func generateWriteAddresses() -> [UInt16] {
        // Same as read for now
        return generateReadAddresses()
    }

    private func generateBluetoothWriteBlocks(data: RadioAppData) -> [BluetoothWriteBlock] {
        var blocks: [BluetoothWriteBlock] = []

        for address in stride(from: UInt16(0), to: UInt16(0x4000), by: 0x80) {
            let first = Codec.encodeBluetoothChannelBlock(for: data, address: address)
            let secondAddress = address + UInt16(SHX8800PRO.framePayloadBytes)
            let second = Codec.encodeBluetoothChannelBlock(for: data, address: secondAddress)
            if first == nil && second == nil {
                continue
            }
            blocks.append(BluetoothWriteBlock(address: address, payload: first ?? Codec.encodeBluetoothChannelBlock(for: data, address: address, includeEmpty: true)!))
            blocks.append(BluetoothWriteBlock(address: secondAddress, payload: second ?? Codec.encodeBluetoothChannelBlock(for: data, address: secondAddress, includeEmpty: true)!))
        }

        for address in generateWriteAddresses() where address >= 0x4000 {
            blocks.append(BluetoothWriteBlock(address: address, payload: Codec.encodeBlock(for: data, address: address)))
        }

        return blocks
    }

    private func groupBluetoothWritePairs(_ blocks: [BluetoothWriteBlock]) throws -> [(BluetoothWriteBlock, BluetoothWriteBlock)] {
        let byAddress = Dictionary(uniqueKeysWithValues: blocks.map { ($0.address, $0) })
        var used = Set<UInt16>()
        var pairs: [(BluetoothWriteBlock, BluetoothWriteBlock)] = []

        for first in blocks {
            if used.contains(first.address) {
                continue
            }

            if let streamSecond = byAddress[first.address + UInt16(SHX8800PRO.framePayloadBytes)], !used.contains(streamSecond.address) {
                used.insert(first.address)
                used.insert(streamSecond.address)
                pairs.append((first, streamSecond))
                continue
            }

            let fallback = blocks.first { candidate in
                if candidate.address == first.address || used.contains(candidate.address) {
                    return false
                }
                let previousAddress = candidate.address >= UInt16(SHX8800PRO.framePayloadBytes)
                    ? candidate.address - UInt16(SHX8800PRO.framePayloadBytes)
                    : nil
                return (previousAddress == nil || byAddress[previousAddress!] == nil) &&
                    byAddress[candidate.address + UInt16(SHX8800PRO.framePayloadBytes)] == nil
            } ?? blocks.first { candidate in
                candidate.address != first.address && !used.contains(candidate.address)
            }

            guard let fallback else {
                throw NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "蓝牙写入失败：\(addressLabel(first.address)) 缺少配对块"])
            }

            used.insert(first.address)
            used.insert(fallback.address)
            pairs.append((first, fallback))
        }

        return pairs
    }

    private func logBluetoothWritePlan(_ pairs: [(BluetoothWriteBlock, BluetoothWriteBlock)]) {
        let preview = pairs
            .prefix(10)
            .map { "\(addressLabel($0.0.address)) + \(addressLabel($0.1.address))" }
            .joined(separator: "；")
        log("蓝牙写入计划：\(pairs.count) 组，\(preview)\(pairs.count > 10 ? " ..." : "")")
    }

    private func addressLabel(_ address: UInt16) -> String {
        if address < 0x4000 {
            let first = Int(address / UInt16(SHX8800PRO.framePayloadBytes)) * 2 + 1
            return "信道 \(first)-\(first + 1)"
        }
        switch address {
        case SHX8800PRO.vfoAddress:
            return "VFO A/B"
        case SHX8800PRO.functionAddress:
            return "功能设置"
        case SHX8800PRO.bankNameAAddress, SHX8800PRO.bankNameBAddress:
            return "区域名称"
        case SHX8800PRO.fmAddress:
            return "FM 收音机"
        case SHX8800PRO.dtmfStartAddress...(SHX8800PRO.dtmfStartAddress + 0x100):
            return "DTMF"
        default:
            return "0x\(String(address, radix: 16).uppercased())"
        }
    }
    
    private func handleReceived(_ data: Data) {
        receiveBuffer.append(data)
        satisfyPendingRead()
    }

    private func drainReceiveBuffer() {
        receiveBuffer.removeAll()
        pendingMatcher = nil
        pendingResponse = nil
        pendingReadToken += 1
        bluetooth.drainWrites()
    }
    
    private func waitForAck(timeout: TimeInterval, completion: @escaping (Data?) -> Void) {
        waitForMatchedResponse(timeout: timeout, matcher: { buffer in
            guard let index = buffer.firstIndex(of: ACK) else { return nil }
            buffer.removeSubrange(0...index)
            return Data([ACK])
        }, completion: completion)
    }

    private func waitForBytes(count: Int, timeout: TimeInterval, completion: @escaping (Data?) -> Void) {
        waitForMatchedResponse(timeout: timeout, matcher: { buffer in
            guard buffer.count >= count else { return nil }
            let response = buffer.prefix(count)
            buffer.removeSubrange(0..<count)
            return Data(response)
        }, completion: completion)
    }

    private func waitForIdent(timeout: TimeInterval, completion: @escaping (Data?) -> Void) {
        waitForMatchedResponse(timeout: timeout, matcher: { buffer in
            guard let start = buffer.firstIndex(of: 0x01) else {
                if buffer.count > 15 {
                    buffer.removeSubrange(0..<(buffer.count - 15))
                }
                return nil
            }
            guard buffer.count >= start + 16 else { return nil }
            let ident = buffer[start..<(start + 16)]
            buffer.removeSubrange(0..<(start + 16))
            return Data(ident)
        }, completion: completion)
    }

    private func waitForFrame(address: UInt16, timeout: TimeInterval, completion: @escaping (Data?) -> Void) {
        let high = UInt8((address >> 8) & 0xFF)
        let low = UInt8(address & 0xFF)
        let expectedHeader = Data([0x52, high, low, 0x40])

        waitForMatchedResponse(timeout: timeout, matcher: { buffer in
            guard !buffer.isEmpty else { return nil }

            while buffer.first == ACK {
                buffer.removeFirst()
            }

            if buffer.count >= expectedHeader.count {
                var index = 0
                while index <= buffer.count - expectedHeader.count {
                    if buffer[index] == 0x52, buffer[index + 1] == high, buffer[index + 2] == low, buffer[index + 3] == 0x40 {
                        let frameEnd = index + SHX8800PRO.frameBytes
                        guard buffer.count >= frameEnd else { return nil }
                        let frame = Data(buffer[index..<frameEnd])
                        buffer.removeSubrange(0..<frameEnd)
                        return frame
                    }
                    index += 1
                }

                let keep = max(expectedHeader.count - 1, 0)
                if buffer.count > keep {
                    buffer.removeSubrange(0..<(buffer.count - keep))
                }
            }

            return nil
        }, completion: completion)
    }

    private func waitForMatchedResponse(timeout: TimeInterval, matcher: @escaping (inout Data) -> Data?, completion: @escaping (Data?) -> Void) {
        pendingReadToken += 1
        let token = pendingReadToken
        pendingMatcher = matcher
        pendingResponse = completion
        satisfyPendingRead()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self else { return }
            if self.pendingReadToken == token, self.pendingResponse != nil {
                self.pendingMatcher = nil
                self.pendingResponse = nil
                completion(nil)
            }
        }
    }

    private func satisfyPendingRead() {
        guard let matcher = pendingMatcher, let handler = pendingResponse else { return }
        if let response = matcher(&receiveBuffer) {
            pendingMatcher = nil
            pendingResponse = nil
            handler(response)
        }
    }
    
    private func log(_ message: String) {
        onLog?(message)
    }
}

// MARK: - Boot Image Protocol
private extension Shx8800ProSession {
    enum BootProtocol {
        static let header: UInt8 = 0xA5
        static let ackPayload: UInt8 = 0x59
        static let cmdWrite: UInt8 = 0x57
        static let cmdHandshake: UInt8 = 0x02
        static let cmdSetAddress: UInt8 = 0x03
        static let cmdErase: UInt8 = 0x04
        static let cmdOver: UInt8 = 0x06
        static let imageAddress: UInt32 = 0x00010000
        static let erasePackageId: UInt16 = 17668
        static let blockBytes = 1024
    }

    func writeBootImageSequence(rgb565: Data, completion: @escaping (Error?) -> Void) {
        onProgress?("切换开机图模式", 0.0)
        enterBootMode { [weak self] entered in
            guard let self else { return }
            guard entered else {
                completion(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "开机图握手失败：设备没有进入刷图模式"]))
                return
            }

            self.bluetooth.send(Data([0x44]))
            self.log("TX 44")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                self.drainReceiveBuffer()
                self.sendBootPacket(
                    command: BootProtocol.cmdHandshake,
                    packageId: 0,
                    payload: asciiBytes("PROGRAM"),
                    label: "图片协议握手",
                    percent: 0.03
                ) { error in
                    if let error {
                        completion(error)
                        return
                    }
                    self.eraseBootImage(rgb565: rgb565, completion: completion)
                }
            }
        }
    }

    func eraseBootImage(rgb565: Data, completion: @escaping (Error?) -> Void) {
        sendBootPacket(
            command: BootProtocol.cmdErase,
            packageId: BootProtocol.erasePackageId,
            payload: buildErasePayload(),
            label: "擦除图片区域",
            percent: 0.08
        ) { error in
            if let error {
                completion(error)
                return
            }
            self.setBootImageAddress(rgb565: rgb565, completion: completion)
        }
    }

    func setBootImageAddress(rgb565: Data, completion: @escaping (Error?) -> Void) {
        sendBootPacket(
            command: BootProtocol.cmdSetAddress,
            packageId: 0,
            payload: buildAddressPayload(BootProtocol.imageAddress),
            label: "设置图片地址",
            percent: 0.12
        ) { error in
            if let error {
                completion(error)
                return
            }
            self.writeBootImageBlocks(rgb565: rgb565, index: 0, completion: completion)
        }
    }

    func writeBootImageBlocks(rgb565: Data, index: Int, completion: @escaping (Error?) -> Void) {
        let total = Int(ceil(Double(rgb565.count) / Double(BootProtocol.blockBytes)))
        guard index < total else {
            onProgress?("结束图片写入", 0.99)
            bluetooth.send(buildBootImagePackage(command: BootProtocol.cmdOver, packageId: 0, payload: asciiBytes("Over")))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.onProgress?("开机图完成", 1.0)
                self.log("开机图写入完成")
                completion(nil)
            }
            return
        }

        let offset = index * BootProtocol.blockBytes
        let end = min(offset + BootProtocol.blockBytes, rgb565.count)
        var chunk = Data(repeating: 0xFF, count: BootProtocol.blockBytes)
        chunk.replaceSubrange(0..<(end - offset), with: rgb565[offset..<end])
        let percent = 0.12 + (Double(index + 1) / Double(total)) * 0.84

        sendBootPacket(
            command: BootProtocol.cmdWrite,
            packageId: UInt16(index),
            payload: chunk,
            label: "写入图片块 \(index + 1)/\(total)",
            percent: percent
        ) { error in
            if let error {
                completion(error)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                self.writeBootImageBlocks(rgb565: rgb565, index: index + 1, completion: completion)
            }
        }
    }

    func enterBootMode(completion: @escaping (Bool) -> Void) {
        let commands = ["PROGRAMSHXPU", "PROGROMSHXU"]
        var commandIndex = 0
        var attempt = 0

        func nextAttempt() {
            guard commandIndex < commands.count else {
                completion(false)
                return
            }

            drainReceiveBuffer()
            let command = commands[commandIndex]
            bluetooth.send(asciiBytes(command))
            log("TX \(command) #\(attempt + 1)")

            waitForAck(timeout: 1.8) { response in
                if response != nil {
                    completion(true)
                    return
                }

                attempt += 1
                if attempt >= 3 {
                    attempt = 0
                    commandIndex += 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    nextAttempt()
                }
            }
        }

        nextAttempt()
    }

    func sendBootPacket(command: UInt8, packageId: UInt16, payload: Data, label: String, percent: Double, completion: @escaping (Error?) -> Void) {
        onProgress?(label, percent)
        log(label)
        let packet = buildBootImagePackage(command: command, packageId: packageId, payload: payload)
        let timeout = command == BootProtocol.cmdErase ? 12.0 : 6.0

        func attempt(_ index: Int) {
            bluetooth.send(packet)
            waitForBootPacket(command: command, timeout: timeout) { response in
                if let response, response.count == 1, response[0] == BootProtocol.ackPayload {
                    completion(nil)
                } else if index < 3 {
                    self.log("\(label)未确认，重试 \(index + 2)/4")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        attempt(index + 1)
                    }
                } else {
                    completion(NSError(domain: "Session", code: -1, userInfo: [NSLocalizedDescriptionKey: "\(label)失败：设备未确认"]))
                }
            }
        }

        attempt(0)
    }

    func waitForBootPacket(command expectedCommand: UInt8, timeout: TimeInterval, completion: @escaping (Data?) -> Void) {
        waitForMatchedResponse(timeout: timeout, matcher: { buffer in
            guard buffer.count >= 6 else { return nil }
            while let headerIndex = buffer.firstIndex(of: BootProtocol.header) {
                if headerIndex > 0 {
                    buffer.removeSubrange(0..<headerIndex)
                }
                guard buffer.count >= 6 else { return nil }
                let command = buffer[1]
                let length = (Int(buffer[4]) << 8) | Int(buffer[5])
                let packetLength = 6 + length + 2
                guard buffer.count >= packetLength else { return nil }
                let packet = buffer.prefix(packetLength)
                buffer.removeSubrange(0..<packetLength)
                guard command == expectedCommand else { continue }
                let expectedCrc = (UInt16(packet[6 + length]) << 8) | UInt16(packet[6 + length + 1])
                let actualCrc = self.crc16Ccitt(Data(packet), offset: 1, count: length + 5)
                guard expectedCrc == actualCrc else { continue }
                return Data(packet[6..<(6 + length)])
            }
            if buffer.count > 5 {
                buffer.removeSubrange(0..<(buffer.count - 5))
            }
            return nil
        }, completion: completion)
    }

    func buildBootImagePackage(command: UInt8, packageId: UInt16, payload: Data) -> Data {
        var packet = Data(repeating: 0x00, count: 6 + payload.count + 2)
        packet[0] = BootProtocol.header
        packet[1] = command
        packet[2] = UInt8((packageId >> 8) & 0xFF)
        packet[3] = UInt8(packageId & 0xFF)
        packet[4] = UInt8((payload.count >> 8) & 0xFF)
        packet[5] = UInt8(payload.count & 0xFF)
        packet.replaceSubrange(6..<(6 + payload.count), with: payload)
        let crc = crc16Ccitt(packet, offset: 1, count: payload.count + 5)
        packet[6 + payload.count] = UInt8((crc >> 8) & 0xFF)
        packet[6 + payload.count + 1] = UInt8(crc & 0xFF)
        return packet
    }

    func buildAddressPayload(_ address: UInt32) -> Data {
        Data([
            UInt8(address & 0xFF),
            UInt8((address >> 8) & 0xFF),
            UInt8((address >> 16) & 0xFF),
            UInt8((address >> 24) & 0xFF)
        ])
    }

    func buildErasePayload() -> Data {
        var payload = buildAddressPayload(BootProtocol.imageAddress)
        payload.append(contentsOf: [0x00, 0x01])
        return payload
    }

    func crc16Ccitt(_ data: Data, offset: Int = 0, count: Int? = nil) -> UInt16 {
        let byteCount = count ?? (data.count - offset)
        var crc: UInt16 = 0
        for index in 0..<byteCount {
            crc ^= UInt16(data[offset + index]) << 8
            for _ in 0..<8 {
                if (crc & 0x8000) == 0x8000 {
                    crc = (crc << 1) ^ 0x1021
                } else {
                    crc <<= 1
                }
            }
        }
        return crc
    }
}

// MARK: - Data Extension
private extension Data {
    var sessionHexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
