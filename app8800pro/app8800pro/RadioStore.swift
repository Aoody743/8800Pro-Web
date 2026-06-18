import Combine
import Foundation
import UIKit

struct OperationProgressState: Equatable, Identifiable {
    enum Tone: Equatable {
        case active
        case success
        case warning
    }

    let id = UUID()
    var title: String
    var message: String
    var progress: Double
    var tone: Tone = .active
    var isIndeterminate = false

    var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }
}

@MainActor
final class RadioStore: ObservableObject {
    @Published var data = RadioAppData.default
    @Published var selectedBankIndex = 0
    @Published var selectedChannelIndex = 0
    @Published var linkState: RadioLinkState = .disconnected
    @Published var uiMode: AppUIMode = .basic
    @Published var notice: NoticeMessage?
    @Published var logs: [String] = []
    @Published var backups: [RadioSnapshot] = []
    @Published var repeaterLibrary: [RepeaterEntry] = []
    @Published var repeaterRegions: [RepeaterRegionGroup] = []
    @Published var repeaterLibraryStatus = "中继台库尚未加载"
    @Published var importedDrafts: [ImportedChannelDraft] = []
    @Published var importSourceText = ""
    @Published var channelSearchText = ""
    @Published var showEmptyChannels = false
    @Published var showFieldHints = true
    @Published var progressNote = "准备就绪"
    @Published var lastOperation = "尚未开始读写"
    @Published var operationProgress: OperationProgressState?

    private let bluetooth = BluetoothManager()
    private var session: Shx8800ProSession?
    private let backupKey = "radio8800pro.ios.backups"
    private var progressDismissTask: Task<Void, Never>?
    private var hasLoadedRepeaterLibrary = false
    private var copiedChannel: Channel?

    init() {
        wireBluetooth()
        loadBackups()
        
        // Initialize session
        session = Shx8800ProSession(bluetooth: bluetooth)
        session?.setLogHandler { [weak self] message in
            Task { @MainActor in
                self?.addLog(message)
            }
        }
        session?.setProgressHandler { [weak self] message, progress in
            Task { @MainActor in
                self?.updateOperation(message: message, progress: progress)
            }
        }
    }

    var currentBankName: String {
        data.bankNames[selectedBankIndex]
    }

    var currentChannel: Channel {
        get { data.channels[selectedBankIndex][selectedChannelIndex] }
        set {
            updateData { data in
                data.channels[selectedBankIndex][selectedChannelIndex] = newValue
            }
        }
    }

    var filteredChannels: [Channel] {
        let bank = data.channels[selectedBankIndex]
        let keyword = channelSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return bank.filter { channel in
            if !showEmptyChannels && (!channel.visible || channel.rxFreq.isEmpty) {
                return false
            }

            guard !keyword.isEmpty else { return true }
            let searchSpace = "\(channel.id) \(channel.name) \(channel.rxFreq) \(channel.txFreq)".lowercased()
            return searchSpace.contains(keyword)
        }
    }

    func selectBank(_ index: Int) {
        guard data.channels.indices.contains(index) else { return }
        selectedBankIndex = index
        selectedChannelIndex = 0
    }

    func selectChannel(id: Int) {
        let nextIndex = max(0, min(id - 1, data.channels[selectedBankIndex].count - 1))
        selectedChannelIndex = nextIndex
    }

    func updateCurrentChannel(_ mutate: (inout Channel) -> Void) {
        var channel = currentChannel
        mutate(&channel)
        channel.visible = !channel.rxFreq.isEmpty
        currentChannel = channel
    }

    func updateFunctionSetting(_ keyPath: WritableKeyPath<RadioFunctionSettings, Int>, value: Int) {
        updateData { data in
            data.functions[keyPath: keyPath] = value
        }
    }

    func updateBankName(index: Int, value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard data.bankNames.indices.contains(index), !trimmed.isEmpty else {
            showWarning("区域名称不能为空")
            return
        }

        updateData { data in
            data.bankNames[index] = String(trimmed.prefix(12))
        }
        showSuccess("已保存区域 \(index + 1) 名称")
    }

    func saveFunctionSettings() {
        showSuccess("功能设置已保存到本地配置。要传输到机器，请回到总览页面点击写频。")
    }

    func updateCallSign(_ value: String) {
        updateData { data in
            data.functions.callSign = String(value.prefix(12))
        }
    }

    func updateVFO(_ mutate: (inout VFOState) -> Void) {
        updateData { data in
            mutate(&data.vfos)
        }
    }

    func updateDTMF(_ mutate: (inout DTMFSettings) -> Void) {
        updateData { data in
            mutate(&data.dtmf)
        }
    }

    func updateFM(_ mutate: (inout FMSettings) -> Void) {
        updateData { data in
            mutate(&data.fm)
        }
    }

    func updateBootImage(_ mutate: (inout BootImageDraft) -> Void) {
        updateData { data in
            mutate(&data.bootImage)
        }
    }

    func clearCurrentChannel() {
        currentChannel = Channel.empty(id: currentChannel.id)
        showSuccess("已清空 CH-\(currentChannel.id)")
    }

    func copyCurrentChannel() {
        copiedChannel = currentChannel
        showSuccess("已复制 CH-\(currentChannel.id)")
    }

    func cutCurrentChannel() {
        copiedChannel = currentChannel
        currentChannel = Channel.empty(id: currentChannel.id)
        showSuccess("已剪切 CH-\(currentChannel.id)")
    }

    func pasteToCurrentChannel() {
        guard var copiedChannel else {
            showWarning("剪贴板里还没有信道")
            return
        }
        copiedChannel.id = currentChannel.id
        currentChannel = copiedChannel
        showSuccess("已粘贴到 CH-\(currentChannel.id)")
    }

    func prepareNewChannelInCurrentBank() -> Bool {
        guard data.channels.indices.contains(selectedBankIndex) else { return false }
        guard let emptyIndex = data.channels[selectedBankIndex].firstIndex(where: { !$0.visible || $0.rxFreq.isEmpty }) else {
            showWarning("当前区域已满，请先清空一个信道或切换区域")
            return false
        }

        updateData { data in
            data.channels[selectedBankIndex][emptyIndex] = Channel.empty(id: emptyIndex + 1)
        }
        selectedChannelIndex = emptyIndex
        channelSearchText = ""
        return true
    }

    func insertEmptyChannelAfterSelection() {
        var bank = data.channels[selectedBankIndex]
        let insertIndex = min(selectedChannelIndex + 1, bank.count - 1)
        bank.insert(Channel.empty(id: insertIndex + 1), at: insertIndex)
        bank = Array(bank.prefix(SHX8800PRO.channelsPerBank))
        renumber(&bank)
        updateData { data in
            data.channels[selectedBankIndex] = bank
        }
        selectedChannelIndex = insertIndex
        showSuccess("已插入空信道")
    }

    func deleteCurrentChannelAndShift() {
        var bank = data.channels[selectedBankIndex]
        guard bank.indices.contains(selectedChannelIndex) else { return }
        bank.remove(at: selectedChannelIndex)
        bank.append(Channel.empty(id: SHX8800PRO.channelsPerBank))
        renumber(&bank)
        updateData { data in
            data.channels[selectedBankIndex] = bank
        }
        selectedChannelIndex = min(selectedChannelIndex, bank.count - 1)
        showSuccess("已删除并上移后续信道")
    }

    func compactCurrentBank() {
        var active = data.channels[selectedBankIndex].filter { $0.visible && !$0.rxFreq.isEmpty }
        let emptyCount = max(0, SHX8800PRO.channelsPerBank - active.count)
        active.append(contentsOf: (0..<emptyCount).map { Channel.empty(id: active.count + $0 + 1) })
        renumber(&active)
        updateData { data in
            data.channels[selectedBankIndex] = active
        }
        selectedChannelIndex = min(selectedChannelIndex, active.count - 1)
        showSuccess("已整理当前区域，空信道移动到末尾")
    }

    func applyRepeater(_ entry: RepeaterEntry) {
        updateCurrentChannel { channel in
            channel.name = String(entry.displayName.prefix(12))
            channel.rxFreq = entry.rxFreq
            channel.txFreq = entry.txFreq.isEmpty ? offsetFrequency(entry.rxFreq, entry.offset) : entry.txFreq
            channel.txTone = normalizeTone(entry.txTone ?? entry.toneText)
            channel.rxTone = normalizeTone(entry.rxTone ?? (entry.toneText.uppercased().contains("TSQ") ? entry.toneText : "OFF"))
            channel.txPower = 0
            channel.bandwidth = 0
            channel.scanAdd = 1
            channel.busyLock = 1
        }
        showSuccess("已将 \(entry.displayName) 写入 \(currentBankName) / CH-\(currentChannel.id)")
    }

    func loadRepeaterLibraryIfNeeded() async {
        guard !hasLoadedRepeaterLibrary else { return }
        hasLoadedRepeaterLibrary = true
        repeaterLibraryStatus = "正在加载 HamCQ 中继台库..."
        do {
            let package = try await RepeaterLibraryLoader.loadPackagedLibrary()
            repeaterLibrary = package.repeaters
            repeaterRegions = package.regions
            repeaterLibraryStatus = "HamCQ \(package.total) 条，更新于 \(package.fetchedAt.prefix(10))"
            addLog("已加载 HamCQ 中继台库 \(package.total) 条")
        } catch {
            repeaterLibrary = DemoData.repeaters
            repeaterRegions = []
            repeaterLibraryStatus = "内置库加载失败，已使用演示数据"
            showWarning("中继台库加载失败: \(error.localizedDescription)")
        }
    }

    func importFromClipboard() {
        importSourceText = UIPasteboard.general.string ?? ""
        parseImportSource()
    }

    func parseImportSource() {
        importedDrafts = ImportParser.parse(importSourceText)
        if importedDrafts.isEmpty {
            showWarning("没有识别到可导入的中继台或频率信息")
        } else {
            showSuccess("识别到 \(importedDrafts.count) 条可导入记录")
        }
    }

    func applyImportedDraft(_ draft: ImportedChannelDraft, appendAfterSelection: Bool) {
        if appendAfterSelection {
            insertDrafts([draft], after: selectedChannelIndex)
        } else {
            currentChannel = draft.makeChannel(id: currentChannel.id)
        }
        showSuccess("已导入 \(draft.title)")
    }

    func applyAllImportedDrafts() {
        guard !importedDrafts.isEmpty else { return }
        insertDrafts(importedDrafts, after: selectedChannelIndex)
        showSuccess("已批量导入 \(importedDrafts.count) 条记录")
    }

    func connectBluetooth() {
        progressNote = "正在准备蓝牙连接"
        bluetooth.startConnection()
    }

    func disconnect() {
        bluetooth.disconnect()
        linkState = .disconnected
        progressNote = "连接已断开"
        notice = NoticeMessage(tone: .neutral, text: "设备已断开。")
    }

    func readRadio() {
        guard linkState.isConnected else {
            showWarning("请先连接蓝牙设备")
            return
        }
        
        createBackup(title: "读频前自动备份", skipWhenEmpty: true)
        beginOperation(title: "读频", message: "正在读取对讲机配置...", progress: 0.02)
        
        session?.readRadio { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.showWarning("读频失败: \(error.localizedDescription)")
                self.finishOperation(message: "读频失败", tone: .warning, dismissAfter: 2.4)
                return
            }
            
            if let result = result {
                self.data = result
                self.showSuccess("读频成功！已读取 \(result.visibleChannelCount) 条信道")
                self.finishOperation(message: "读频完成", tone: .success)
                self.createBackup(title: "读频成功 \(Formatters.shortDate.string(from: .now))", skipWhenEmpty: true)
            }
        }
    }

    func writeRadio() {
        guard linkState.isConnected else {
            showWarning("请先连接蓝牙设备")
            return
        }
        
        createBackup(title: "写频前自动备份", skipWhenEmpty: true)
        beginOperation(title: "写频", message: "正在写入对讲机配置...", progress: 0.02)
        
        session?.writeRadio(data: data) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.showWarning("写频失败: \(error.localizedDescription)")
                self.finishOperation(message: "写频失败", tone: .warning, dismissAfter: 2.4)
                return
            }
            
            self.showSuccess("写频成功！配置已写入对讲机")
            self.finishOperation(message: "写频完成", tone: .success)
        }
    }

    func writeBootLogo() {
        showWarning("开机图写入仍在开发中，暂不开放。")
    }

    func sendHandshakeTest() {
        bluetooth.sendASCII("PROGRAMSHXPU")
        addLog("手动发送握手字串 PROGRAMSHXPU")
    }

    func sendEndFrameTest() {
        bluetooth.send(Data([0x45]))
        addLog("手动发送结束字节 45")
    }

    func createBackup(title: String, skipWhenEmpty: Bool = false) {
        if skipWhenEmpty && data.visibleChannelCount == 0 {
            addLog("已跳过自动备份：当前没有有效信道")
            return
        }
        let snapshot = RadioSnapshot(title: title, createdAt: .now, data: data)
        backups.insert(snapshot, at: 0)
        persistBackups()
    }

    func restore(_ snapshot: RadioSnapshot) {
        data = snapshot.data
        showSuccess("已恢复备份：\(snapshot.title)")
    }

    func restoreBackup(_ snapshot: RadioSnapshot) {
        data = snapshot.data
        data.updatedAt = .now
        showSuccess("已恢复备份「\(snapshot.title)」")
        addLog("恢复备份: \(snapshot.title)")
    }

    func deleteBackup(_ snapshot: RadioSnapshot) {
        backups.removeAll { $0.id == snapshot.id }
        persistBackups()
        showSuccess("已删除备份「\(snapshot.title)」")
        addLog("删除备份: \(snapshot.title)")
    }

    func clearLogs() {
        logs.removeAll()
        addLog("日志已清空")
    }

    func updateBootLogo(_ logoData: Data?) {
        updateData { data in
            data.bootLogo = logoData
            data.bootImage.name = logoData == nil ? "" : "iOS 开机图"
            data.bootImage.width = SHX8800PRO.bootImageWidth
            data.bootImage.height = SHX8800PRO.bootImageHeight
            data.bootImage.previewNote = logoData == nil ? "未设置开机图" : "已生成 \(logoData?.count ?? 0) bytes 开机图数据"
        }
        showSuccess(logoData == nil ? "已恢复默认开机图" : "开机图已更新")
    }

    private func insertDrafts(_ drafts: [ImportedChannelDraft], after index: Int) {
        var bank = data.channels[selectedBankIndex]
        var insertionIndex = max(0, min(index, bank.count - 1))

        for draft in drafts {
            if insertionIndex >= bank.count {
                break
            }
            bank[insertionIndex] = draft.makeChannel(id: insertionIndex + 1)
            insertionIndex += 1
        }

        updateData { data in
            data.channels[selectedBankIndex] = bank
        }
    }

    private func renumber(_ channels: inout [Channel]) {
        for index in channels.indices {
            channels[index].id = index + 1
            channels[index].visible = !channels[index].rxFreq.isEmpty
        }
    }

    private func wireBluetooth() {
        bluetooth.onLog = { [weak self] line in
            Task { @MainActor in
                self?.addLog(line)
            }
        }

        bluetooth.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.handleBluetoothState(state)
            }
        }

        bluetooth.onReceive = { [weak self] data in
            Task { @MainActor in
                self?.addLog("收到 \(data.count) bytes")
            }
        }
    }

    private func handleBluetoothState(_ state: BluetoothManager.State) {
        switch state {
        case .idle:
            linkState = .disconnected
            progressNote = "等待连接设备"
        case let .unavailable(message):
            linkState = .unavailable(message)
            progressNote = message
            notice = NoticeMessage(tone: .warning, text: message)
        case .scanning:
            linkState = .scanning
            progressNote = "正在搜索蓝牙设备"
            notice = NoticeMessage(tone: .neutral, text: "正在搜索 8800Pro 蓝牙设备…")
        case .connecting:
            linkState = .connecting
            progressNote = "正在建立蓝牙连接"
        case .discovering:
            linkState = .discovering
            progressNote = "正在发现服务与特征"
        case .connected:
            linkState = .connected(.bluetooth)
            progressNote = "蓝牙链路已连接"
            notice = NoticeMessage(tone: .success, text: "蓝牙链路已连接，可以先做握手测试或准备接协议。")
        case let .failed(message):
            linkState = .failed(message)
            progressNote = message
            notice = NoticeMessage(tone: .warning, text: message)
        }
    }

    private func addLog(_ line: String) {
        logs.insert("\(Formatters.shortDate.string(from: .now))  \(line)", at: 0)
        if logs.count > 300 {
            logs = Array(logs.prefix(300))
        }
    }

    func showSuccess(_ text: String) {
        notice = NoticeMessage(tone: .success, text: text)
        addLog(text)
    }

    private func showWarning(_ text: String) {
        notice = NoticeMessage(tone: .warning, text: text)
        addLog(text)
    }

    private func beginOperation(title: String, message: String, progress: Double = 0) {
        progressDismissTask?.cancel()
        lastOperation = title
        progressNote = message
        operationProgress = OperationProgressState(
            title: title,
            message: message,
            progress: progress,
            tone: .active
        )
    }

    private func updateOperation(message: String, progress: Double) {
        progressNote = message
        guard var state = operationProgress else {
            operationProgress = OperationProgressState(
                title: lastOperation,
                message: message,
                progress: progress,
                tone: .active
            )
            return
        }
        state.message = message
        state.progress = max(state.normalizedProgress, min(max(progress, 0), 1))
        state.tone = .active
        operationProgress = state
    }

    private func finishOperation(message: String, tone: OperationProgressState.Tone, dismissAfter: TimeInterval = 1.25) {
        progressNote = message
        var state = operationProgress ?? OperationProgressState(
            title: lastOperation,
            message: message,
            progress: 1,
            tone: tone
        )
        state.message = message
        state.progress = 1
        state.tone = tone
        operationProgress = state

        progressDismissTask?.cancel()
        progressDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(dismissAfter * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.operationProgress = nil
            }
        }
    }

    private func seedStarterChannels() {
        guard data.visibleChannelCount == 0 else { return }
        updateData { data in
            data.bankNames[1] = "中继台"

            let repeaters = DemoData.repeaters
            for (index, repeater) in repeaters.enumerated() where index < data.channels[1].count {
                data.channels[1][index] = Channel(
                    id: index + 1,
                    rxFreq: repeater.rxFreq,
                    rxTone: repeater.toneText.uppercased().contains("TSQ") ? normalizeTone(repeater.toneText) : "OFF",
                    txFreq: offsetFrequency(repeater.rxFreq, repeater.offset),
                    txTone: normalizeTone(repeater.toneText),
                    txPower: 0,
                    bandwidth: 0,
                    scanAdd: 0,
                    busyLock: 1,
                    pttID: 0,
                    signalGroup: 0,
                    name: String(repeater.displayName.prefix(12)),
                    visible: true
                )
            }
        }
        selectedBankIndex = 1
    }

    private func loadBackups() {
        guard let raw = UserDefaults.standard.data(forKey: backupKey),
              let stored = try? JSONDecoder().decode([RadioSnapshot].self, from: raw)
        else {
            return
        }
        backups = stored
    }

    private func persistBackups() {
        if let raw = try? JSONEncoder().encode(backups) {
            UserDefaults.standard.set(raw, forKey: backupKey)
        }
    }

    private func normalizeTone(_ source: String) -> String {
        source
            .replacingOccurrences(of: "TSQ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "T", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func offsetFrequency(_ rx: String, _ offset: String) -> String {
        guard let rxValue = Double(rx), let offsetValue = Double(offset) else { return rx }
        return String(format: "%.5f", rxValue + offsetValue)
    }

    private func updateData(_ mutate: (inout RadioAppData) -> Void) {
        var next = data
        mutate(&next)
        next.updatedAt = .now
        data = next
    }
}
