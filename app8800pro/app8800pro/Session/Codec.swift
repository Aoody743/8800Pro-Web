import Foundation

// MARK: - Type aliases for protocol compatibility
// The codec expects names from the web version; we map them to RadioModels types
public typealias VfoInfos = VFOState
public typealias FunctionSettings = RadioFunctionSettings
public typealias DtmfSettings = DTMFSettings
public typealias FmSettings = FMSettings
public typealias AppData = RadioAppData

// MARK: - Codec implementation
public enum Codec {
    
    /// Encode a 64-byte block for a given memory address
    public static func encodeBlock(for data: AppData, address: UInt16) -> Data {
        var payload = getBasePayload(data, address: address, fill: address < 0x4000 ? 0xFF : 0x00)
        
        // Channel blocks (0x0000 - 0x3FFF)
        if address < 0x4000 {
            let firstChannelIndex = Int(address / 64) * 2
            let bank1 = firstChannelIndex / 64
            let index1 = firstChannelIndex % 64
            let bank2 = (firstChannelIndex + 1) / 64
            let index2 = (firstChannelIndex + 1) % 64
            
            if bank1 < data.channels.count && index1 < data.channels[bank1].count {
                let ch1Base = payload.count >= 32 ? payload.subdata(in: 0..<32) : nil
                let ch1Data = encodeChannel(data.channels[bank1][index1], base: ch1Base, preserveUnknownFlags: hasRawBlock(data, address: address), blockAddress: address)
                payload.replaceSubrange(0..<32, with: ch1Data)
            }
            
            if bank2 < data.channels.count && index2 < data.channels[bank2].count {
                let ch2Base = payload.count >= 64 ? payload.subdata(in: 32..<64) : nil
                let ch2Data = encodeChannel(data.channels[bank2][index2], base: ch2Base, preserveUnknownFlags: hasRawBlock(data, address: address), blockAddress: nil)
                payload.replaceSubrange(32..<64, with: ch2Data)
            }
            
            return payload
        }
        
        // VFO block (0x7000)
        if address == SHX8800PRO.vfoAddress {
            let vfoAData = encodeVfo(data.vfos, side: .A, base: payload.subdata(in: 0..<32))
            let vfoBData = encodeVfo(data.vfos, side: .B, base: payload.subdata(in: 32..<64))
            payload.replaceSubrange(0..<32, with: vfoAData)
            payload.replaceSubrange(32..<64, with: vfoBData)
            return payload
        }
        
        // Function settings block (0x7100)
        if address == SHX8800PRO.functionAddress {
            return encodeFunctionSettings(data, base: payload)
        }

        if address >= SHX8800PRO.dtmfStartAddress && address <= SHX8800PRO.dtmfStartAddress + 0x100 {
            return encodeDTMF(data.dtmf, address: address, base: payload)
        }

        if address == SHX8800PRO.bankNameAAddress || address == SHX8800PRO.bankNameBAddress {
            let start = address == SHX8800PRO.bankNameAAddress ? 0 : 4
            if !hasRawBlock(data, address: address) {
                payload = Data(repeating: 0xFF, count: 64)
            }
            for index in 0..<4 where data.bankNames.indices.contains(start + index) {
                let offset = index * 16
                let name = data.bankNames[start + index].trimmingCharacters(in: .whitespacesAndNewlines)
                let currentName = hasRawBlock(data, address: address) ? decodeRadioText(payload, offset: offset, maxBytes: 12) : ""
                if hasRawBlock(data, address: address) && (name.isEmpty || name == currentName) {
                    continue
                }
                let fill: UInt8 = payload.subdata(in: offset..<(offset + 12)).contains(0) ? 0 : 0xFF
                let encoded = encodeRadioText(name, maxBytes: 12, fill: fill)
                payload.replaceSubrange(offset..<(offset + encoded.count), with: encoded)
                payload.replaceSubrange((offset + 12)..<(offset + 16), with: Data(repeating: 0xFF, count: 4))
            }
            return payload
        }

        if address == SHX8800PRO.fmAddress {
            payload.replaceSubrange(0..<2, with: encodeFMFrequency(data.fm.currentFreq))
            for index in 0..<min(30, data.fm.channels.count) {
                let offset = 2 + index * 2
                payload.replaceSubrange(offset..<(offset + 2), with: encodeFMFrequency(data.fm.channels[index]))
            }
            return payload
        }
        
        // Legacy boot logo blocks. The real 128x128 RGB565 image uses the dedicated boot protocol.
        if address >= SHX8800PRO.bootLogoAddress && address < SHX8800PRO.bootLogoAddress + 0x400 {
            if let logoData = data.bootLogo, !logoData.isEmpty {
                let offset = Int(address - SHX8800PRO.bootLogoAddress)
                let end = min(offset + 64, logoData.count)
                if offset < logoData.count {
                    payload.replaceSubrange(0..<(end - offset), with: logoData[offset..<end])
                }
            }
            return payload
        }
        
        return payload
    }
    
    /// Apply a received 64-byte block to AppData
    public static func applyBlock(to data: inout AppData, address: UInt16, frame: Data) {
        let payload = frame.count == 68 ? frame.subdata(in: 4..<68) : frame
        if payload.count == SHX8800PRO.framePayloadBytes {
            data.rawBlocks = data.rawBlocks ?? [:]
            data.rawBlocks?[blockKey(address)] = Array(payload)
        }
        
        // Channel blocks
        if address < 0x4000 {
            let firstChannelIndex = Int(address / 64) * 2
            
            if payload.count >= 32 {
                let ch1 = decodeChannel(payload.subdata(in: 0..<32), id: (firstChannelIndex % 64) + 1, blockAddress: address)
                setChannel(&data, flatIndex: firstChannelIndex, channel: ch1)
            }
            
            if payload.count >= 64 {
                let ch2 = decodeChannel(payload.subdata(in: 32..<64), id: ((firstChannelIndex + 1) % 64) + 1)
                setChannel(&data, flatIndex: firstChannelIndex + 1, channel: ch2)
            }
            
            return
        }
        
        // VFO block
        if address == SHX8800PRO.vfoAddress {
            if payload.count >= 32 {
                decodeVfo(&data.vfos, payload: payload.subdata(in: 0..<32), side: .A)
            }
            if payload.count >= 64 {
                decodeVfo(&data.vfos, payload: payload.subdata(in: 32..<64), side: .B)
            }
            return
        }
        
        // Function settings block
        if address == SHX8800PRO.functionAddress {
            decodeFunctionSettings(&data, payload: payload)
            return
        }

        if address >= SHX8800PRO.dtmfStartAddress && address <= SHX8800PRO.dtmfStartAddress + 0x100 {
            decodeDTMF(&data.dtmf, address: address, payload: payload)
            return
        }

        if address == SHX8800PRO.bankNameAAddress || address == SHX8800PRO.bankNameBAddress {
            let start = address == SHX8800PRO.bankNameAAddress ? 0 : 4
            for index in 0..<4 where data.bankNames.indices.contains(start + index) {
                data.bankNames[start + index] = decodeRadioText(payload, offset: index * 16, maxBytes: 12)
            }
            return
        }

        if address == SHX8800PRO.fmAddress {
            data.fm.currentFreq = decodeFMFrequency(payload, offset: 0)
            for index in 0..<min(30, data.fm.channels.count) {
                data.fm.channels[index] = decodeFMFrequency(payload, offset: 2 + index * 2)
            }
            return
        }
        
        // Boot logo blocks
        if address >= SHX8800PRO.bootLogoAddress && address < SHX8800PRO.bootLogoAddress + 0x400 {
            let offset = Int(address - SHX8800PRO.bootLogoAddress)
            if data.bootLogo == nil {
                data.bootLogo = Data(repeating: 0x00, count: SHX8800PRO.bootImageBytes)
            }
            if var logoData = data.bootLogo {
                let end = min(offset + payload.count, logoData.count)
                if offset < logoData.count {
                    logoData.replaceSubrange(offset..<end, with: payload.prefix(end - offset))
                    data.bootLogo = logoData
                }
            }
            return
        }
    }

    public static func encodeBluetoothChannelBlock(for data: AppData, address: UInt16, includeEmpty: Bool = false) -> Data? {
        let firstChannelIndex = Int(address / UInt16(SHX8800PRO.framePayloadBytes)) * 2
        let first = channel(atFlatIndex: firstChannelIndex, in: data)
        let second = channel(atFlatIndex: firstChannelIndex + 1, in: data)
        let firstHasFrequency = !(first?.rxFreq.isEmpty ?? true)
        let secondHasFrequency = !(second?.rxFreq.isEmpty ?? true)

        guard includeEmpty || firstHasFrequency || secondHasFrequency else {
            return nil
        }

        let hasRaw = hasRawBlock(data, address: address)
        var payload = getBasePayload(data, address: address, fill: 0xFF)
        if let first, firstHasFrequency {
            let base = payload.subdata(in: 0..<32)
            payload.replaceSubrange(0..<32, with: encodeChannel(first, base: base, preserveUnknownFlags: hasRaw, blockAddress: address))
        } else {
            payload.replaceSubrange(0..<32, with: sanitizeEmptyChannelPayload(payload.subdata(in: 0..<32), blockAddress: address))
        }

        if let second, secondHasFrequency {
            let base = payload.subdata(in: 32..<64)
            payload.replaceSubrange(32..<64, with: encodeChannel(second, base: base, preserveUnknownFlags: hasRaw))
        } else {
            payload.replaceSubrange(32..<64, with: sanitizeEmptyChannelPayload(payload.subdata(in: 32..<64)))
        }

        return payload
    }
    
    // MARK: - Channel encoding/decoding
    
    private static func encodeChannel(_ channel: Channel, base: Data? = nil, preserveUnknownFlags: Bool = false, blockAddress: UInt16? = nil) -> Data {
        let baseIsUsable = base.map { !isBleFrameHeaderPollutedChannel($0, blockAddress: blockAddress) && isValidBcdFrequency($0, offset: 0) } ?? false
        var payload = baseIsUsable ? Data(base!) : Data(repeating: 0xFF, count: 32)
        guard !channel.rxFreq.isEmpty else { return Data(repeating: 0xFF, count: 32) }

        payload.replaceSubrange(0..<4, with: encodeChannelFrequency(channel.rxFreq))
        payload.replaceSubrange(4..<8, with: encodeChannelFrequency(channel.txFreq.isEmpty ? channel.rxFreq : channel.txFreq))
        payload.replaceSubrange(8..<10, with: encodeTone(channel.rxTone))
        payload.replaceSubrange(10..<12, with: encodeTone(channel.txTone))
        if !baseIsUsable || !preserveUnknownFlags || Int(payload[12] % 20) != channel.signalGroup {
            payload[12] = UInt8(channel.signalGroup & 0x1F)
        }
        
        // Settings
        if !baseIsUsable || !preserveUnknownFlags || Int(payload[13] & 0x03) != channel.pttID {
            payload[13] = UInt8(channel.pttID & 0x03)
        }
        payload[14] = UInt8(channel.txPower & 0x03)
        let preservedFlags = baseIsUsable && preserveUnknownFlags ? Int(payload[15]) & 0x03 : 0
        let bandwidthFlag = (channel.bandwidth & 0x01) << 6
        let busyLockFlag = (channel.busyLock & 0x01) << 3
        let scanAddFlag = (channel.scanAdd & 0x01) << 2
        payload[15] = UInt8(preservedFlags | bandwidthFlag | busyLockFlag | scanAddFlag)
        
        let nameData = encodeChannelName(channel.name, base: baseIsUsable ? payload : nil)
        payload.replaceSubrange(20..<(20 + nameData.count), with: nameData)
        
        return payload
    }
    
    private static func encodeChannelName(_ name: String, base: Data?) -> Data {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let base, base.count >= 32 {
            let currentName = decodeRadioText(base, offset: 20, maxBytes: 12)
            if normalized.isEmpty || normalized == currentName {
                return base.subdata(in: 20..<32)
            }
        }
        let fill: UInt8 = base?.subdata(in: 20..<32).contains(0) == true ? 0 : 0xFF
        return encodeRadioText(normalized, maxBytes: 12, fill: fill)
    }
    
    private static func decodeChannel(_ payload: Data, id: Int, blockAddress: UInt16? = nil) -> Channel {
        guard payload.count >= 32 else {
            return Channel.empty(id: id)
        }
        
        if payload[0] == 0xFF ||
            payload[1] == 0xFF ||
            payload[3] == 0 ||
            isBleFrameHeaderPollutedChannel(payload, blockAddress: blockAddress) ||
            !isValidBcdFrequency(payload, offset: 0) {
            return Channel.empty(id: id)
        }

        let rxFreq = decodeChannelFrequency(payload, offset: 0)
        let txFreq = payload[4] != 0xFF && payload[5] != 0xFF ? decodeChannelFrequency(payload, offset: 4) : ""
        let rxTone = decodeTone(payload, offset: 8)
        let txTone = decodeTone(payload, offset: 10)
        let signalGroup = Int(payload[12] % 20)
        
        let pttID = Int(payload[13] & 0x03)
        let txPower = Int(payload[14] & 0x03)
        let bandwidth = Int((payload[15] >> 6) & 0x01)
        let busyLock = Int((payload[15] >> 3) & 0x01)
        let scanAdd = Int((payload[15] >> 2) & 0x01)
        
        // Decode name
        var name = ""
        name = decodeRadioText(payload, offset: 20, maxBytes: 12)
        
        return Channel(
            id: id,
            rxFreq: rxFreq,
            rxTone: rxTone,
            txFreq: txFreq,
            txTone: txTone,
            txPower: txPower,
            bandwidth: bandwidth,
            scanAdd: scanAdd,
            busyLock: busyLock,
            pttID: pttID,
            signalGroup: signalGroup,
            name: name,
            visible: true
        )
    }
    
    // MARK: - VFO encoding/decoding
    
    enum VfoSide {
        case A
        case B
    }
    
    private static func encodeVfo(_ vfos: VFOState, side: VfoSide, base: Data? = nil) -> Data {
        var payload = base?.count == 32 ? Data(base!) : Data(repeating: 0xFF, count: 32)
        
        switch side {
        case .A:
            payload.replaceSubrange(0..<8, with: encodeVFOFrequency(vfos.vfoAFreq))
            payload.replaceSubrange(8..<10, with: encodeTone(vfos.vfoARxTone))
            payload.replaceSubrange(10..<12, with: encodeTone(vfos.vfoATxTone))
            payload[13] = UInt8(vfos.vfoABusyLock & 0x01)
            payload[14] = UInt8(((vfos.vfoADirection & 0x03) << 4) | (vfos.vfoASignalGroup & 0x0F))
            payload[16] = UInt8((vfos.vfoATxPower & 0x03))
            payload[17] = UInt8((vfos.vfoABandwidth & 0x01) << 6)
            payload[19] = UInt8(vfos.vfoAStep & 0x07)
            payload.replaceSubrange(20..<27, with: encodeOffset(vfos.vfoAOffset))
        case .B:
            payload.replaceSubrange(0..<8, with: encodeVFOFrequency(vfos.vfoBFreq))
            payload.replaceSubrange(8..<10, with: encodeTone(vfos.vfoBRxTone))
            payload.replaceSubrange(10..<12, with: encodeTone(vfos.vfoBTxTone))
            payload[13] = UInt8(vfos.vfoBBusyLock & 0x01)
            payload[14] = UInt8(((vfos.vfoBDirection & 0x03) << 4) | (vfos.vfoBSignalGroup & 0x0F))
            payload[16] = UInt8((vfos.vfoBTxPower & 0x03))
            payload[17] = UInt8((vfos.vfoBBandwidth & 0x01) << 6)
            payload[19] = UInt8(vfos.vfoBStep & 0x07)
            payload.replaceSubrange(20..<27, with: encodeOffset(vfos.vfoBOffset))
        }
        
        return payload
    }
    
    private static func decodeVfo(_ vfos: inout VFOState, payload: Data, side: VfoSide) {
        guard payload.count >= 32 else { return }
        
        let busyLock = Int(payload[13] & 0x01)
        let signalGroup = Int(payload[14] & 0x0F)
        let direction = Int((payload[14] >> 4) & 0x03)
        let txPower = Int(payload[16] & 0x03)
        let bandwidth = Int((payload[17] >> 6) & 0x01)
        let step = Int(payload[19] & 0x07)
        
        switch side {
        case .A:
            vfos.vfoAFreq = decodeVFOFrequency(payload, offset: 0)
            vfos.vfoARxTone = decodeTone(payload, offset: 8)
            vfos.vfoATxTone = decodeTone(payload, offset: 10)
            vfos.vfoABusyLock = busyLock
            vfos.vfoASignalGroup = signalGroup
            vfos.vfoADirection = direction
            vfos.vfoATxPower = txPower
            vfos.vfoABandwidth = bandwidth
            vfos.vfoAStep = step
            vfos.vfoAOffset = decodeOffset(payload, offset: 20)
        case .B:
            vfos.vfoBFreq = decodeVFOFrequency(payload, offset: 0)
            vfos.vfoBRxTone = decodeTone(payload, offset: 8)
            vfos.vfoBTxTone = decodeTone(payload, offset: 10)
            vfos.vfoBBusyLock = busyLock
            vfos.vfoBSignalGroup = signalGroup
            vfos.vfoBDirection = direction
            vfos.vfoBTxPower = txPower
            vfos.vfoBBandwidth = bandwidth
            vfos.vfoBStep = step
            vfos.vfoBOffset = decodeOffset(payload, offset: 20)
        }
    }
    
    // MARK: - Function settings encoding/decoding
    
    private static func encodeFunctionSettings(_ data: RadioAppData, base: Data? = nil) -> Data {
        let settings = data.functions
        var payload = base?.count == 64 ? Data(base!) : Data(repeating: 0xFF, count: 64)
        
        payload[0] = UInt8(settings.sql)
        payload[1] = UInt8(settings.saveMode)
        payload[2] = UInt8(settings.vox)
        payload[3] = UInt8(settings.backlight)
        payload[4] = UInt8(settings.dualStandby)
        payload[5] = UInt8(settings.tot)
        payload[6] = UInt8(settings.beep)
        payload[7] = UInt8(settings.voice)
        payload[9] = UInt8(settings.sideTone)
        payload[10] = UInt8(settings.scanMode)
        payload[11] = UInt8(data.vfos.pttID & 0x03)
        payload[12] = UInt8(settings.pttDelay)
        payload[13] = UInt8(settings.chADisplay)
        payload[14] = UInt8(settings.chBDisplay)
        payload[16] = UInt8(settings.autoLock)
        payload[17] = UInt8(settings.alarmMode)
        payload[18] = UInt8(settings.localSosTone)
        payload[20] = UInt8(settings.tailClear)
        payload[21] = UInt8(settings.rptTailClear)
        payload[22] = UInt8(settings.rptTailDetect)
        payload[23] = UInt8(settings.roger)
        payload[25] = UInt8(settings.fmEnable)
        payload[26] = UInt8(settings.chAWorkmode | (settings.chBWorkmode << 4))
        payload[27] = UInt8(settings.keyLock)
        payload[28] = UInt8(settings.powerOnDisplay)
        payload[30] = UInt8(settings.tone)
        payload[32] = UInt8(settings.voxDelay)
        payload[33] = UInt8(settings.menuQuitTime)
        payload[34] = UInt8(settings.micGain)
        payload[36] = UInt8(settings.powerOnDelay)
        payload[37] = UInt8(settings.voxSwitch)
        payload[42] = UInt8(settings.key2Short)
        payload[43] = UInt8(settings.key2Long)
        payload[46] = UInt8(settings.currentBankA)
        payload[47] = UInt8(settings.currentBankB)
        payload[49] = UInt8(settings.bluetoothMicGain)
        payload[50] = UInt8(settings.bluetoothAudioGain)
        
        payload.replaceSubrange(52..<58, with: encodeRadioText(encodeCallSign(settings.callSign), maxBytes: 6, fill: 0))
        
        return payload
    }
    
    private static func decodeFunctionSettings(_ data: inout RadioAppData, payload: Data) {
        guard payload.count >= 64 else { return }
        var settings = data.functions
        
        settings.sql = Int(payload[0] % 10)
        settings.saveMode = Int(payload[1] % 4)
        settings.vox = Int(payload[2] % 10)
        settings.backlight = Int(payload[3] % 9)
        settings.dualStandby = Int(payload[4] % 2)
        settings.tot = Int(payload[5] % 9)
        settings.beep = Int(payload[6] % 2)
        settings.voice = Int(payload[7] % 2)
        settings.sideTone = Int(payload[9] % 4)
        settings.scanMode = Int(payload[10] % 3)
        data.vfos.pttID = Int(payload[11] % 4)
        settings.pttDelay = Int(payload[12] % 16)
        settings.chADisplay = Int(payload[13] % 3)
        settings.chBDisplay = Int(payload[14] % 3)
        settings.autoLock = Int(payload[16] % 7)
        settings.alarmMode = Int(payload[17] % 3)
        settings.localSosTone = Int(payload[18] % 2)
        settings.tailClear = Int(payload[20] % 2)
        settings.rptTailClear = Int(payload[21] % 11)
        settings.rptTailDetect = Int(payload[22] % 11)
        settings.roger = Int(payload[23] % 2)
        settings.fmEnable = Int(payload[25] % 2)
        settings.chAWorkmode = Int((payload[26] & 0x0F) % 2)
        settings.chBWorkmode = Int(((payload[26] >> 4) & 0x0F) % 2)
        settings.keyLock = Int(payload[27] % 2)
        settings.powerOnDisplay = Int(payload[28] % 22)
        settings.tone = Int(payload[30] % 4)
        settings.voxDelay = Int(payload[32] % 16)
        settings.menuQuitTime = Int(payload[33] % 11)
        settings.micGain = Int(payload[34] % 3)
        settings.powerOnDelay = Int(payload[36] % 15)
        settings.voxSwitch = Int(payload[37] % 2)
        settings.key2Short = Int(payload[42] % 5)
        settings.key2Long = Int(payload[43] % 5)
        settings.currentBankA = Int(payload[46] % 8)
        settings.currentBankB = Int(payload[47] % 8)
        settings.bluetoothMicGain = Int(payload[49] % 5)
        settings.bluetoothAudioGain = Int(payload[50] % 5)
        
        // Decode call sign
        if payload.count >= 58 {
            settings.callSign = decodeRadioText(payload, offset: 52, maxBytes: 6)
        }
        data.functions = settings
    }

    // MARK: - DTMF/FM and value codecs

    private static let dtmfChars = Array("0123456789ABCD*#")

    private static func encodeDTMF(_ settings: DTMFSettings, address: UInt16, base: Data? = nil) -> Data {
        var payload = base?.count == 64 ? Data(base!) : Data(repeating: 0xFF, count: 64)

        func writeWord(_ offset: Int, _ word: String) {
            for (index, char) in word.uppercased().prefix(6).enumerated() {
                if let charIndex = dtmfChars.firstIndex(of: char), offset + index < payload.count {
                    payload[offset + index] = UInt8(charIndex)
                }
            }
        }

        switch address {
        case SHX8800PRO.dtmfStartAddress:
            writeWord(0, settings.localID)
            payload[6] = UInt8(settings.pttID)
            payload[7] = UInt8(settings.wordTime)
            payload[8] = UInt8(settings.idleTime)
            if settings.groups.indices.contains(0) { writeWord(32, settings.groups[0]) }
            if settings.groups.indices.contains(1) { writeWord(48, settings.groups[1]) }
        case SHX8800PRO.dtmfStartAddress + 0x40:
            for (slot, group) in [2, 3, 4, 5].enumerated() where settings.groups.indices.contains(group) {
                writeWord(slot * 16, settings.groups[group])
            }
        case SHX8800PRO.dtmfStartAddress + 0x80:
            for (slot, group) in [6, 7, 8, 9].enumerated() where settings.groups.indices.contains(group) {
                writeWord(slot * 16, settings.groups[group])
            }
        case SHX8800PRO.dtmfStartAddress + 0xC0:
            for (slot, group) in [10, 11, 12, 13].enumerated() where settings.groups.indices.contains(group) {
                writeWord(slot * 16, settings.groups[group])
            }
        case SHX8800PRO.dtmfStartAddress + 0x100:
            if settings.groups.indices.contains(14) { writeWord(0, settings.groups[14]) }
        default:
            break
        }

        return payload
    }

    private static func decodeDTMF(_ settings: inout DTMFSettings, address: UInt16, payload: Data) {
        func readWord(_ offset: Int) -> String {
            var text = ""
            for index in 0..<6 {
                let cursor = offset + index
                guard cursor < payload.count, payload[cursor] != 0xFF else { break }
                text.append(dtmfChars[Int(payload[cursor] % 16)])
            }
            return text
        }

        switch address {
        case SHX8800PRO.dtmfStartAddress:
            settings.localID = readWord(0)
            settings.pttID = Int(payload.count > 6 ? payload[6] : 0) % max(1, RadioChoices.pttID.count)
            settings.wordTime = Int(payload.count > 7 ? payload[7] : 0) % 16
            settings.idleTime = Int(payload.count > 8 ? payload[8] : 0) % 16
            if settings.groups.indices.contains(0) { settings.groups[0] = readWord(32) }
            if settings.groups.indices.contains(1) { settings.groups[1] = readWord(48) }
        case SHX8800PRO.dtmfStartAddress + 0x40:
            for (slot, group) in [2, 3, 4, 5].enumerated() where settings.groups.indices.contains(group) {
                settings.groups[group] = readWord(slot * 16)
            }
        case SHX8800PRO.dtmfStartAddress + 0x80:
            for (slot, group) in [6, 7, 8, 9].enumerated() where settings.groups.indices.contains(group) {
                settings.groups[group] = readWord(slot * 16)
            }
        case SHX8800PRO.dtmfStartAddress + 0xC0:
            for (slot, group) in [10, 11, 12, 13].enumerated() where settings.groups.indices.contains(group) {
                settings.groups[group] = readWord(slot * 16)
            }
        case SHX8800PRO.dtmfStartAddress + 0x100:
            if settings.groups.indices.contains(14) { settings.groups[14] = readWord(0) }
        default:
            break
        }
    }

    private static func normalizedFrequency(_ value: String) -> String? {
        guard let parsed = Double(value), parsed >= SHX8800PRO.minFreqMhz, parsed < SHX8800PRO.maxFreqMhz else {
            return nil
        }
        let scaled = (parsed * 100_000).rounded(.toNearestOrAwayFromZero)
        let stepped = floor(scaled / 125) * 125
        return String(format: "%.5f", stepped / 100_000)
    }

    private static func encodeChannelFrequency(_ value: String) -> Data {
        var bytes = Data(repeating: 0xFF, count: 4)
        guard let normalized = normalizedFrequency(value) else { return bytes }
        var numeric = Int(normalized.replacingOccurrences(of: ".", with: "")) ?? 0
        for index in 0..<4 {
            let pair = numeric % 100
            numeric /= 100
            bytes[index] = UInt8((((pair / 10) << 4) | (pair % 10)) & 0xFF)
        }
        return bytes
    }

    private static func decodeChannelFrequency(_ payload: Data, offset: Int) -> String {
        guard payload.count >= offset + 4 else { return "" }
        var numeric = 0
        for index in stride(from: 3, through: 0, by: -1) {
            let value = payload[offset + index]
            let pair = Int(((value >> 4) & 0x0F) * 10 + (value & 0x0F))
            numeric = numeric * 100 + pair
        }
        let text = String(format: "%08d", numeric)
        let split = text.index(text.startIndex, offsetBy: 3)
        return "\(text[..<split]).\(text[split...])"
    }

    private static func encodeVFOFrequency(_ value: String) -> Data {
        var bytes = Data(repeating: 0xFF, count: 8)
        guard let normalized = normalizedFrequency(value) else { return bytes }
        var numeric = Int(normalized.replacingOccurrences(of: ".", with: "")) ?? 0
        for index in stride(from: 7, through: 0, by: -1) {
            bytes[index] = UInt8(numeric % 10)
            numeric /= 10
        }
        return bytes
    }

    private static func decodeVFOFrequency(_ payload: Data, offset: Int) -> String {
        guard payload.count >= offset + 8 else { return "" }
        let digits = (0..<8).map { String(payload[offset + $0] % 10) }.joined()
        let split = digits.index(digits.startIndex, offsetBy: 3)
        return "\(digits[..<split]).\(digits[split...])"
    }

    private static func encodeOffset(_ value: String) -> Data {
        var bytes = Data(repeating: 0xFF, count: 7)
        let parts = value.split(separator: ".", maxSplits: 1).map(String.init)
        let integer = Int(parts.first ?? "0") ?? 0
        let decimalText = String((parts.count > 1 ? parts[1] : "").padding(toLength: 4, withPad: "0", startingAt: 0).prefix(4))
        var numeric = integer * 10_000 + (Int(decimalText) ?? 0)
        for index in stride(from: 6, through: 0, by: -1) {
            bytes[index] = UInt8(numeric % 10)
            numeric /= 10
        }
        return bytes
    }

    private static func decodeOffset(_ payload: Data, offset: Int) -> String {
        guard payload.count >= offset + 7 else { return "000.0000" }
        let digits = (0..<7).map { String(payload[offset + $0] % 10) }.joined()
        let split = digits.index(digits.startIndex, offsetBy: 3)
        return "\(digits[..<split]).\(digits[split...])"
    }

    private static func encodeFMFrequency(_ freq: Int) -> Data {
        guard freq > 0 else { return Data([0, 0]) }
        return Data([UInt8(freq & 0xFF), UInt8((freq >> 8) & 0xFF)])
    }

    private static func decodeFMFrequency(_ payload: Data, offset: Int) -> Int {
        guard payload.count > offset + 1, payload[offset] != 0xFF, payload[offset + 1] != 0xFF else { return 0 }
        let value = Int(payload[offset]) + (Int(payload[offset + 1]) << 8)
        return (650...1080).contains(value) ? value : 0
    }

    private static func encodeTone(_ value: String) -> Data {
        guard !value.isEmpty, value != "OFF" else { return Data([0, 0]) }
        let numeric = Int(value.replacingOccurrences(of: ".", with: "")) ?? 0
        guard numeric > 0 else { return Data([0, 0]) }
        return Data([UInt8(numeric & 0xFF), UInt8((numeric >> 8) & 0xFF)])
    }

    private static func decodeTone(_ payload: Data, offset: Int) -> String {
        guard payload.count > offset + 1 else { return "OFF" }
        let first = payload[offset]
        let second = payload[offset + 1]
        guard first != 0, first != 0xFF, second != 0 else { return "OFF" }
        let text = String((Int(second) << 8) + Int(first))
        guard text.count > 1 else { return "OFF" }
        return "\(text.dropLast()).\(text.suffix(1))"
    }

    private static let radioTextEncoding = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
    )

    private static func encodeRadioText(_ input: String, maxBytes: Int, fill: UInt8 = 0xFF) -> Data {
        var bytes = Data(repeating: fill, count: maxBytes)
        var cursor = 0
        for char in input.trimmingCharacters(in: .whitespacesAndNewlines) {
            let text = "\(char)"
            let encoded = text.data(using: radioTextEncoding) ??
                text.data(using: .utf8) ??
                Data("?".utf8)
            guard cursor + encoded.count <= maxBytes else { break }
            bytes.replaceSubrange(cursor..<(cursor + encoded.count), with: encoded)
            cursor += encoded.count
        }
        return bytes
    }

    private static func decodeRadioText(_ payload: Data, offset: Int, maxBytes: Int) -> String {
        guard payload.count > offset else { return "" }
        let end = min(payload.count, offset + maxBytes)
        let slice = payload[offset..<end]
        let effective = slice.prefix { $0 != 0xFF && $0 != 0 }
        let data = Data(effective)
        return (String(data: data, encoding: radioTextEncoding) ??
            String(data: data, encoding: .utf8) ??
            "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func encodeCallSign(_ input: String) -> String {
        var result = ""
        for scalar in input.uppercased().unicodeScalars {
            let value = scalar.value
            let isDigit = value >= 48 && value <= 57
            let isUppercaseAscii = value >= 65 && value <= 90
            if isDigit || isUppercaseAscii {
                result.unicodeScalars.append(scalar)
                if result.count >= 6 { break }
            }
        }
        return result
    }
    
    // MARK: - Helper functions

    private static func getBasePayload(_ data: AppData, address: UInt16, fill: UInt8 = 0x00) -> Data {
        if let raw = data.rawBlocks?[blockKey(address)], raw.count == SHX8800PRO.framePayloadBytes {
            return Data(raw)
        }
        return Data(repeating: fill, count: SHX8800PRO.framePayloadBytes)
    }

    private static func hasRawBlock(_ data: AppData, address: UInt16) -> Bool {
        data.rawBlocks?[blockKey(address)]?.count == SHX8800PRO.framePayloadBytes
    }

    private static func blockKey(_ address: UInt16) -> String {
        String(format: "%04X", address)
    }

    private static func isBleFrameHeaderPollutedChannel(_ payload: Data, blockAddress: UInt16?) -> Bool {
        if isAnyChannelWriteHeader(payload) {
            return true
        }
        guard let blockAddress, payload.count >= 4 else {
            return false
        }
        return payload[0] == 0x57 &&
            payload[1] == UInt8((blockAddress >> 8) & 0xFF) &&
            payload[2] == UInt8(blockAddress & 0xFF) &&
            payload[3] == 0x40
    }

    private static func isAnyChannelWriteHeader(_ payload: Data) -> Bool {
        guard payload.count >= 4, payload[0] == 0x57, payload[3] == 0x40 else {
            return false
        }
        let address = (UInt16(payload[1]) << 8) | UInt16(payload[2])
        return address < 0x4000 && address % 0x40 == 0
    }

    private static func isValidBcdFrequency(_ payload: Data, offset: Int) -> Bool {
        guard payload.count >= offset + 4 else {
            return false
        }
        for index in offset..<(offset + 4) {
            if (payload[index] & 0x0F) > 9 || ((payload[index] >> 4) & 0x0F) > 9 {
                return false
            }
        }
        guard let freq = Double(decodeChannelFrequency(payload, offset: offset)) else {
            return false
        }
        return freq >= SHX8800PRO.minFreqMhz && freq < SHX8800PRO.maxFreqMhz
    }

    private static func sanitizeEmptyChannelPayload(_ payload: Data, blockAddress: UInt16? = nil) -> Data {
        if isBleFrameHeaderPollutedChannel(payload, blockAddress: blockAddress) || !isValidBcdFrequency(payload, offset: 0) {
            return Data(repeating: 0xFF, count: 32)
        }
        return Data(payload)
    }

    private static func channel(atFlatIndex flatIndex: Int, in data: AppData) -> Channel? {
        let bank = flatIndex / SHX8800PRO.channelsPerBank
        let index = flatIndex % SHX8800PRO.channelsPerBank
        guard data.channels.indices.contains(bank), data.channels[bank].indices.contains(index) else {
            return nil
        }
        return data.channels[bank][index]
    }
    
    private static func setChannel(_ data: inout AppData, flatIndex: Int, channel: Channel) {
        let bank = flatIndex / 64
        let index = flatIndex % 64
        
        while data.channels.count <= bank {
            data.channels.append([])
        }
        
        while data.channels[bank].count <= index {
            data.channels[bank].append(Channel.empty(id: data.channels[bank].count + 1))
        }
        
        data.channels[bank][index] = channel
    }
}
