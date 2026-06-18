import Foundation

enum RadioConnectionKind: String, CaseIterable, Identifiable, Codable {
    case bluetooth = "蓝牙"
    case usb = "USB"

    var id: String { rawValue }
}

enum AppUIMode: String, CaseIterable, Identifiable {
    case basic = "基础"
    case advanced = "高级"

    var id: String { rawValue }
}

enum RadioLinkState: Equatable {
    case disconnected
    case unavailable(String)
    case scanning
    case connecting
    case discovering
    case connected(RadioConnectionKind)
    case failed(String)

    var title: String {
        switch self {
        case .disconnected:
            return "未连接"
        case let .unavailable(message):
            return message
        case .scanning:
            return "正在搜索设备"
        case .connecting:
            return "正在连接"
        case .discovering:
            return "正在初始化链路"
        case let .connected(kind):
            return "\(kind.rawValue) 已连接"
        case let .failed(message):
            return message
        }
    }

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

struct NoticeMessage: Identifiable, Equatable {
    enum Tone {
        case neutral
        case success
        case warning
    }

    let id = UUID()
    var tone: Tone
    var text: String
}

struct Channel: Identifiable, Codable, Hashable {
    var id: Int
    var rxFreq: String
    var rxTone: String
    var txFreq: String
    var txTone: String
    var txPower: Int
    var bandwidth: Int
    var scanAdd: Int
    var busyLock: Int
    var pttID: Int
    var signalGroup: Int
    var name: String
    var visible: Bool

    static func empty(id: Int) -> Channel {
        Channel(
            id: id,
            rxFreq: "",
            rxTone: "OFF",
            txFreq: "",
            txTone: "OFF",
            txPower: 0,
            bandwidth: 0,
            scanAdd: 0,
            busyLock: 0,
            pttID: 0,
            signalGroup: 0,
            name: "",
            visible: false
        )
    }
}

public struct VFOState: Codable, Hashable {
    var pttID = 0
    var vfoAFreq = "440.62500"
    var vfoBFreq = "145.62500"
    var vfoAOffset = "00.0000"
    var vfoBOffset = "00.0000"
    var vfoARxTone = "OFF"
    var vfoATxTone = "OFF"
    var vfoBRxTone = "OFF"
    var vfoBTxTone = "OFF"
    var vfoATxPower = 0
    var vfoBTxPower = 0
    var vfoABandwidth = 0
    var vfoBBandwidth = 0
    var vfoAStep = 0
    var vfoBStep = 0
    var vfoABusyLock = 0
    var vfoBBusyLock = 0
    var vfoASignalGroup = 0
    var vfoBSignalGroup = 0
    var vfoADirection = 0
    var vfoBDirection = 0
}

public struct RadioFunctionSettings: Codable, Hashable {
    var sql = 3
    var saveMode = 1
    var vox = 1
    var backlight = 5
    var dualStandby = 0
    var tot = 2
    var beep = 1
    var voice = 1
    var sideTone = 0
    var scanMode = 1
    var pttDelay = 4
    var chADisplay = 0
    var chBDisplay = 0
    var autoLock = 2
    var alarmMode = 0
    var localSosTone = 1
    var tailClear = 1
    var rptTailClear = 5
    var rptTailDetect = 5
    var roger = 0
    var fmEnable = 0
    var chAWorkmode = 0
    var chBWorkmode = 0
    var keyLock = 0
    var powerOnDisplay = 0
    var tone = 2
    var voxDelay = 5
    var menuQuitTime = 1
    var micGain = 1
    var powerOnDelay = 0
    var voxSwitch = 0
    var key2Short = 0
    var key2Long = 1
    var currentBankA = 0
    var currentBankB = 0
    var bluetoothAudioGain = 2
    var bluetoothMicGain = 2
    var callSign = ""
}

public struct DTMFSettings: Codable, Hashable {
    var localID = "100"
    var pttID = 0
    var wordTime = 1
    var idleTime = 1
    var groups = Array(repeating: "", count: 15)
    var groupNames = (1 ... 15).map { "成员\($0)" }
}

public struct FMSettings: Codable, Hashable {
    var currentFreq = 904
    var channels = Array(repeating: 0, count: 30)
}

struct BootImageDraft: Codable, Hashable {
    var name = ""
    var width = 128
    var height = 128
    var previewNote = "待接入图片选择与 RGB565 转换"
}

struct RadioSnapshot: Identifiable, Codable, Hashable {
    let id = UUID()
    var title: String
    var createdAt: Date
    var data: RadioAppData
}

public struct RadioAppData: Codable, Hashable {
    var model = "SHX8800PRO"
    var bankNames: [String]
    var channels: [[Channel]]
    var vfos: VFOState
    var functions: RadioFunctionSettings
    var dtmf: DTMFSettings
    var fm: FMSettings
    var bootImage: BootImageDraft
    var bootLogo: Data?
    var rawBlocks: [String: [UInt8]]?
    var updatedAt: Date

    static var `default`: RadioAppData {
        let bankNames = ["区域一", "区域二", "区域三", "区域四", "区域五", "区域六", "区域七", "区域八"]
        let channels = (0 ..< 8).map { _ in
            (0 ..< 64).map { Channel.empty(id: $0 + 1) }
        }
        var dtmf = DTMFSettings()
        dtmf.groups = (101 ... 115).map { String($0) }

        return RadioAppData(
            bankNames: bankNames,
            channels: channels,
            vfos: VFOState(),
            functions: RadioFunctionSettings(),
            dtmf: dtmf,
            fm: FMSettings(),
            bootImage: BootImageDraft(),
            bootLogo: nil,
            rawBlocks: nil,
            updatedAt: .now
        )
    }

    var visibleChannelCount: Int {
        channels.flatMap { $0 }.filter { $0.visible && !$0.rxFreq.isEmpty }.count
    }
}

struct RepeaterEntry: Identifiable, Codable, Hashable {
    var id: String
    var region: String
    var province: String
    var provinceCode: Int
    var city: String
    var cityCode: Int
    var area: String
    var name: String
    var callSign: String?
    var updatedAt: String
    var kind: String
    var rxFreq: String
    var txFreq: String
    var offset: String
    var toneText: String
    var txTone: String?
    var rxTone: String?
    var mode: String?
    var remark: String?
    var source: String?
    var sourceUser: String?
    var sourceCreatedAt: Int?

    var displayName: String {
        if let callSign, !callSign.isEmpty {
            return "\(name) \(callSign)"
        }
        return name
    }

    var locationText: String {
        [region, province, city]
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }
}

struct RepeaterProvinceGroup: Identifiable, Codable, Hashable {
    var id: Int { code }
    var name: String
    var code: Int
    var analogTotal: Int
    var digiTotal: Int
    var municipality: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case code
        case analogTotal = "analog_total"
        case digiTotal = "digi_total"
        case municipality
    }
}

struct RepeaterRegionGroup: Identifiable, Codable, Hashable {
    var id: String { label }
    var label: String
    var children: [RepeaterProvinceGroup]
}

struct RepeaterLibraryPackage: Codable, Hashable {
    var source: String
    var fetchedAt: String
    var total: Int
    var regions: [RepeaterRegionGroup]
    var repeaters: [RepeaterEntry]
}

struct HelpTopic: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var detail: String
}

struct ChangelogEntry: Identifiable, Hashable {
    let id = UUID()
    var version: String
    var title: String
    var detail: String
}

struct ImportedChannelDraft: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var sourceText: String
    var rxFreq: String
    var txFreq: String
    var tone: String
    var notes: String

    func makeChannel(id: Int) -> Channel {
        Channel(
            id: id,
            rxFreq: rxFreq,
            rxTone: tone == "OFF" ? "OFF" : tone,
            txFreq: txFreq,
            txTone: tone,
            txPower: 0,
            bandwidth: 0,
            scanAdd: 0,
            busyLock: 1,
            pttID: 0,
            signalGroup: 0,
            name: String(title.prefix(12)),
            visible: true
        )
    }
}

enum ToneLibrary {
    static let ctcss: [String] = [
        "OFF", "67.0", "69.3", "71.9", "74.4", "77.0", "79.7", "82.5", "85.4", "88.5", "91.5", "94.8",
        "97.4", "100.0", "103.5", "107.2", "110.9", "114.8", "118.8", "123.0", "127.3", "131.8", "136.5",
        "141.3", "146.2", "151.4", "156.7", "159.8", "162.2", "165.5", "167.9", "171.3", "173.8", "177.3",
        "179.9", "183.5", "186.2", "189.9", "192.8", "196.6", "199.5", "203.5", "206.5", "210.7", "218.1",
        "225.7", "229.1", "233.6", "241.8", "250.3", "254.1"
    ]
}

enum DemoData {
    static let repeaters: [RepeaterEntry] = [
        RepeaterEntry(id: "sz-br7jok", region: "7 区", province: "广东省", provinceCode: 440000, city: "深圳", cityCode: 440300, area: "7区", name: "梧桐山", callSign: "BR7JOK", updatedAt: "2026/06/12", kind: "模拟", rxFreq: "439.46250", txFreq: "434.46250", offset: "-5.0", toneText: "TSQ88.5", txTone: "88.5", rxTone: "88.5", mode: nil, remark: nil, source: "Demo", sourceUser: nil, sourceCreatedAt: nil),
        RepeaterEntry(id: "sz-br7lzl", region: "7 区", province: "广东省", provinceCode: 440000, city: "深圳", cityCode: 440300, area: "7区", name: "南山", callSign: "BR7LZL", updatedAt: "2026/02/09", kind: "混合", rxFreq: "439.35000", txFreq: "434.35000", offset: "-5.0", toneText: "TSQ77.0", txTone: "77.0", rxTone: "77.0", mode: "FM/C4FM", remark: nil, source: "Demo", sourceUser: nil, sourceCreatedAt: nil),
        RepeaterEntry(id: "gz-br7jdl", region: "7 区", province: "广东省", provinceCode: 440000, city: "广州", cityCode: 440100, area: "7区", name: "越秀", callSign: "BR7JDL", updatedAt: "2026/04/06", kind: "混合", rxFreq: "439.05000", txFreq: "434.05000", offset: "-5.0", toneText: "TSQ82.5", txTone: "82.5", rxTone: "82.5", mode: "C4FM", remark: nil, source: "Demo", sourceUser: nil, sourceCreatedAt: nil),
        RepeaterEntry(id: "zs-br7jbk", region: "7 区", province: "广东省", provinceCode: 440000, city: "中山", cityCode: 442000, area: "7区", name: "粤桂中山", callSign: "BR7JBK", updatedAt: "2026/06/16", kind: "模拟", rxFreq: "439.12500", txFreq: "434.12500", offset: "-5.0", toneText: "TSQ88.5", txTone: "88.5", rxTone: "88.5", mode: nil, remark: nil, source: "Demo", sourceUser: nil, sourceCreatedAt: nil),
        RepeaterEntry(id: "hd-main", region: "7 区", province: "广东省", provinceCode: 440000, city: "惠东", cityCode: 441300, area: "7区", name: "惠东总台", callSign: nil, updatedAt: "2026/06/16", kind: "模拟", rxFreq: "439.97000", txFreq: "431.97000", offset: "-8.0", toneText: "TSQ88.5", txTone: "88.5", rxTone: "88.5", mode: nil, remark: nil, source: "Demo", sourceUser: nil, sourceCreatedAt: nil),
        RepeaterEntry(id: "hd-peak", region: "7 区", province: "广东省", provinceCode: 440000, city: "惠东", cityCode: 441300, area: "7区", name: "高山台", callSign: nil, updatedAt: "2026/06/16", kind: "模拟", rxFreq: "438.97000", txFreq: "430.27000", offset: "-8.7", toneText: "TSQ82.5", txTone: "82.5", rxTone: "82.5", mode: nil, remark: nil, source: "Demo", sourceUser: nil, sourceCreatedAt: nil)
    ]

    static let guideConcepts: [(String, String)] = [
        ("信道", "一个信道就是一组可收可发的无线电参数，最常见的是频率、亚音、功率和名称。"),
        ("区域", "区域可以理解成一个信道分组。你可以按用途拆成中继、车队、应急和打星。"),
        ("读频", "先把机器原本的数据读出来，再开始改，最稳。"),
        ("写频", "把 App 里的配置写回机器。正式写回前建议先留备份。"),
        ("CTCSS / DCS", "这是亚音和数字静噪。普通通联不会就先用 OFF。"),
        ("中继台", "中继通常会要求收发频率和亚音配套，直接用中继台库最省心。")
    ]

    static let featureCards: [(String, String)] = [
        ("总览", "看连接状态、当前区域、备份数量和建议流程。"),
        ("信道", "编辑最常用的信道内容，也能从中继台库和粘贴文本导入。"),
        ("功能", "调整静噪、背光、VOX、扫描和双守等整机设置。"),
        ("工具", "VFO、DTMF、FM、开机图、打星、文件和蓝牙链路调试都在这里。"),
        ("教程", "把术语先讲清楚，再去操作对讲机。"),
        ("关于", "查看项目说明、免责声明、致谢和更新日志。")
    ]

    static let settingsHelp: [HelpTopic] = [
        HelpTopic(title: "静噪等级 SQL", detail: "值越高，越弱的杂音就越不容易被打开。听不到远台时可以先适当调低。"),
        HelpTopic(title: "双守", detail: "让机器同时盯住 A / B 两个区域。新手如果觉得切换太乱，可以先关闭。"),
        HelpTopic(title: "自动锁", detail: "一段时间不操作后自动锁键，避免误碰。发现机器按不动时要先看看是否被锁住。"),
        HelpTopic(title: "A / B 工作模式", detail: "信道模式就是从写好的信道里选；频率模式更像手动直输频率。"),
        HelpTopic(title: "显示模式", detail: "可以决定屏幕上优先显示名称、频率还是信道号。")
    ]

    static let dtmfHelp: [HelpTopic] = [
        HelpTopic(title: "本机 ID", detail: "DTMF 设备识别号。需要联动呼叫时再填写，平时可以保留默认。"),
        HelpTopic(title: "发码时长", detail: "每个按键音持续多久。对方设备识别不稳时，可以把时长调长一点。"),
        HelpTopic(title: "组呼列表", detail: "把常用的 DTMF 编码先存下来，后面就不用每次手动敲。")
    ]

    static let fmHelp: [HelpTopic] = [
        HelpTopic(title: "FM 广播", detail: "这是收音机，不是业余电台信道。常用电台可以先写进记忆位。"),
        HelpTopic(title: "当前频点", detail: "例如 904 表示 90.4 MHz。")
    ]

    static let updateLogs: [ChangelogEntry] = [
        ChangelogEntry(version: "v0.1", title: "原生 SwiftUI 方向确定", detail: "iOS 端改为原生 SwiftUI 实现，避免 Flutter 在 iPhone 上常见的区域挤压和显示错位。"),
        ChangelogEntry(version: "v0.2", title: "蓝牙链路骨架接通", detail: "加入 FFE0 / FFE1 服务发现、通知监听、状态反馈和通信日志，为后续接入完整写频协议打底。"),
        ChangelogEntry(version: "v0.3", title: "中继台与粘贴导入", detail: "支持从内置中继台库直接带入，也支持从文字里识别频率、频差和亚音一键导入。"),
        ChangelogEntry(version: "v0.4", title: "移动端流程重做", detail: "围绕新手流程重排页面，把连接、读频、信道编辑、备份和恢复放到更顺手的位置。"),
        ChangelogEntry(version: "v0.5", title: "对齐网页蓝牙协议", detail: "iOS 写频改为网页验证过的流式 BLE 链路，读频保留 raw block，写回时保护未知字段、区域名称和正常信道，过滤 404 / 412 这类头污染频率。")
    ]
}

enum Formatters {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

enum RadioChoices {
    static let power = ["高功率", "中功率", "低功率"]
    static let bandwidth = ["宽带", "窄带"]
    static let onOff = ["关闭", "开启"]
    static let scanMode = ["时间", "载波", "搜索"]
    static let workMode = ["信道模式", "频率模式"]
    static let displayMode = ["名称", "频率", "信道号"]
    static let stepOptions = ["2.5K", "5K", "6.25K", "10K", "12.5K", "25K"]
    static let autoLock = ["关闭", "5秒", "10秒", "15秒"]
    static let backlight = ["常亮", "5秒", "10秒", "20秒", "30秒"]
    static let pttID = ["关闭", "BOT", "EOT", "BOT+EOT"]
}
