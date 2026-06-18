import CoreBluetooth
import Foundation

public final class BluetoothManager: NSObject {
    enum State: Equatable {
        case idle
        case unavailable(String)
        case scanning
        case connecting
        case discovering
        case connected
        case failed(String)
    }

    var onStateChange: ((State) -> Void)?
    var onLog: ((String) -> Void)?
    var onReceive: ((Data) -> Void)?

    private let serviceUUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    private let characteristicUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
    private let preferredName = "walkie-talkie"

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private struct PendingWrite {
        var data: Data
        var completion: ((Error?) -> Void)?
    }

    private var writeQueue: [PendingWrite] = []
    private var isWriting = false
    private var scanTimeoutTask: DispatchWorkItem?
    private(set) var state: State = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    func startConnection() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
            return
        }
        guard let central else { return }
        handlePowerState(for: central)
    }

    func disconnect() {
        scanTimeoutTask?.cancel()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        writeCharacteristic = nil
        writeQueue.removeAll()
        isWriting = false
        updateState(.idle)
        log("蓝牙连接已断开")
    }

    func sendASCII(_ string: String) {
        guard let data = string.data(using: .ascii) else { return }
        send(data)
    }

    func send(_ data: Data, completion: ((Error?) -> Void)? = nil) {
        guard state == .connected, let peripheral, let writeCharacteristic else {
            log("蓝牙链路未就绪，无法发送 \(data.count) bytes")
            completion?(NSError(domain: "BluetoothManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "蓝牙链路未就绪"]))
            return
        }

        if shouldWriteAsSinglePacket(data) {
            writeQueue.append(PendingWrite(data: data, completion: completion))
            processWriteQueue(peripheral: peripheral, characteristic: writeCharacteristic)
            return
        }

        let mtu = max(20, peripheral.maximumWriteValueLength(for: .withResponse))
        var offset = 0
        while offset < data.count {
            let nextOffset = min(offset + mtu, data.count)
            let chunk = data.subdata(in: offset ..< nextOffset)
            let isLast = nextOffset >= data.count
            writeQueue.append(PendingWrite(data: chunk, completion: isLast ? completion : nil))
            offset = nextOffset
        }
        processWriteQueue(peripheral: peripheral, characteristic: writeCharacteristic)
    }

    func drainWrites() {
        writeQueue.removeAll()
        isWriting = false
    }

    private func handlePowerState(for central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            beginScan()
        case .unsupported:
            updateState(.unavailable("当前设备不支持蓝牙"))
        case .unauthorized:
            updateState(.unavailable("蓝牙权限未授权"))
        case .poweredOff:
            updateState(.unavailable("蓝牙未开启"))
        default:
            updateState(.unavailable("蓝牙暂不可用"))
        }
    }

    private func beginScan() {
        guard let central else { return }
        scanTimeoutTask?.cancel()
        updateState(.scanning)
        log("开始扫描 \(preferredName) / FFE0")
        central.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

        let timeoutTask = DispatchWorkItem { [weak self] in
            guard let self, self.state == .scanning else { return }
            self.central?.stopScan()
            self.updateState(.failed("扫描超时，请确认对讲机蓝牙已开启"))
            self.log("扫描超时")
        }
        scanTimeoutTask = timeoutTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutTask)
    }

    private func updateState(_ next: State) {
        state = next
    }

    private func log(_ line: String) {
        onLog?(line)
    }

    private func processWriteQueue(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        guard !isWriting, let pending = writeQueue.first else { return }
        isWriting = true
        peripheral.writeValue(pending.data, for: characteristic, type: .withResponse)
        log("TX \(pending.data.hexString)")
    }

    private func shouldWriteAsSinglePacket(_ data: Data) -> Bool {
        if data.count <= 20 { return true }
        if data.count == SHX8800PRO.framePayloadBytes { return true }
        if data.count == SHX8800PRO.frameBytes { return true }
        return data.count == 4 && data.first == 0x57
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        handlePowerState(for: central)
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "").lowercased()
        if !name.contains(preferredName) && !name.contains("walkie") {
            return
        }

        scanTimeoutTask?.cancel()
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        updateState(.connecting)
        log("发现设备 \(peripheral.name ?? "未知设备")，准备连接")
        central.connect(peripheral, options: nil)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        updateState(.discovering)
        log("蓝牙已连接，开始发现服务")
        peripheral.discoverServices([serviceUUID])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        updateState(.failed("蓝牙连接失败"))
        log("蓝牙连接失败 \(error?.localizedDescription ?? "")")
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        writeCharacteristic = nil
        writeQueue.removeAll()
        isWriting = false
        if let error {
            updateState(.failed("设备断开连接"))
            log("设备断开连接 \(error.localizedDescription)")
        } else {
            updateState(.idle)
            log("设备断开连接")
        }
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            updateState(.failed("服务发现失败"))
            log("服务发现失败 \(error?.localizedDescription ?? "")")
            return
        }

        let service = peripheral.services?.first(where: { $0.uuid == serviceUUID })
        guard let service else {
            updateState(.failed("未发现 FFE0 服务"))
            return
        }
        peripheral.discoverCharacteristics([characteristicUUID], for: service)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            updateState(.failed("特征发现失败"))
            log("特征发现失败 \(error?.localizedDescription ?? "")")
            return
        }

        let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID })
        guard let characteristic else {
            updateState(.failed("未发现 FFE1 特征"))
            return
        }

        writeCharacteristic = characteristic
        updateState(.discovering)
        log("发现 FFE1，正在开启通知")
        peripheral.setNotifyValue(true, for: characteristic)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == characteristicUUID else { return }

        if let error {
            writeCharacteristic = nil
            updateState(.failed("FFE1 通知开启失败"))
            log("FFE1 通知开启失败 \(error.localizedDescription)")
            return
        }

        guard characteristic.isNotifying else {
            writeCharacteristic = nil
            updateState(.failed("FFE1 通知未开启"))
            log("FFE1 通知未开启，蓝牙链路不可用")
            return
        }

        // Match Web Bluetooth's startNotifications() barrier: only expose the
        // link after CoreBluetooth confirms notifications are actually active.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self, weak peripheral] in
            guard let self, peripheral === self.peripheral else { return }
            self.updateState(.connected)
            self.log("FFE1 通知已开启，蓝牙链路已就绪")
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            log("接收失败 \(error?.localizedDescription ?? "")")
            return
        }
        guard let value = characteristic.value else { return }
        log("RX \(value.hexString)")
        onReceive?(value)
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            log("写入失败 \(error.localizedDescription)")
        }
        let completion = writeQueue.first?.completion
        if !writeQueue.isEmpty {
            writeQueue.removeFirst()
        }
        completion?(error)
        isWriting = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.012) { [weak self, weak peripheral, weak characteristic] in
            guard let self, let peripheral, let characteristic else { return }
            self.processWriteQueue(peripheral: peripheral, characteristic: characteristic)
        }
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
