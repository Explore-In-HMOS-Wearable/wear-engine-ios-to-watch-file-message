import SwiftUI
import WearEngineSDK

@MainActor
final class WearEngineViewModel: ObservableObject, WearEngineManagerDelegate {
    @Published var devices: [WearableDevice] = []
    @Published var selectedDevice: WearableDevice?
    @Published var messages: [P2PMessage] = []
    @Published var currentMessage = ""
    @Published var logs: [LogEntry] = []
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var isAuthorized = false

    @Published var isLongSendInProgress = false
    @Published var isAlertManuallyDismissed = false

    private let manager = ServiceLocator.shared.wearEngineManager

    init() {
        manager.delegate = self
        log("WearEngine SDK initialized")
        checkAuthorizationOnLaunch()
    }

    private func checkAuthorizationOnLaunch() {
        manager.getAvailableDevicesWithRetry(retries: 2, delay: 0.6) { [weak self] infos, error in
            guard let self else { return }
            if let error {
                self.log("Initial device query error: \(error)")
            } else {
                self.isAuthorized = true
                self.devices = infos.map { .init(id: $0.id, name: $0.name, isConnected: $0.isConnected) }
                self.log("Devices loaded at launch")
                self.manager.preloadConnectedIfAny { current in
                    guard let cur = current, cur.isConnected else { return }
                    self.selectedDevice = WearableDevice(id: cur.id, name: cur.name, isConnected: true)
                }
                self.manager.resubscribeToDevices()
            }
        }
    }

    nonisolated func didLog(_ text: String) {
        Task { @MainActor in self.log(text) }
    }

    nonisolated func didReceiveMessage(_ text: String) {
        Task { @MainActor in
            self.messages.append(.init(content: text, timestamp: Date(), isOutgoing: false))
        }
    }

    nonisolated func didUpdateDeviceList(_ infos: [WearEngineManager.WearableDeviceInfo]) {
        Task { @MainActor in
            self.devices = infos.map { .init(id: $0.id, name: $0.name, isConnected: $0.isConnected) }
            if let cur = self.manager.currentDeviceCached, cur.isConnected {
                self.selectedDevice = .init(id: cur.id, name: cur.name, isConnected: true)
            }
            if let sel = self.selectedDevice,
               let updated = infos.first(where: { $0.id == sel.id }) {
                self.selectedDevice = .init(id: updated.id, name: updated.name, isConnected: updated.isConnected)
            }
        }
    }

    func requestAuthorization() {
        log("Requesting authorization")
        manager.requestAuthorization { [weak self] ok, msg in
            guard let self else { return }
            guard ok else {
                self.isAuthorized = false
                return self.alert(msg)
            }
            self.isAuthorized = true
            self.alert("Authorization successful")
            self.manager.refreshDevicesAndResubscribe()
            self.manager.getAvailableDevicesWithRetry(retries: 2, delay: 0.6) { [weak self] infos, error in
                guard let self else { return }
                if let error { self.log("Post-auth device query failed: \(error)"); return }
                self.devices = infos.map { .init(id: $0.id, name: $0.name, isConnected: $0.isConnected) }
                self.manager.preloadConnectedIfAny { current in
                    guard let cur = current, cur.isConnected else { return }
                    self.selectedDevice = WearableDevice(id: cur.id, name: cur.name, isConnected: true)
                }
            }
        }
    }

    func loadDevices() {
        if !isAuthorized {
            log("Not authorized: requesting authorization before refreshing devices")
            requestAuthorization()
            return
        }
        manager.getAvailableDevicesWithRetry(retries: 3, delay: 0.7) { [weak self] infos, error in
            guard let self else { return }
            if let error { return self.alert(error) }
            self.devices = infos.map { .init(id: $0.id, name: $0.name, isConnected: $0.isConnected) }
            self.manager.resubscribeToDevices()
        }
    }

    func connectSelectedIfAny() {
        guard let sel = selectedDevice else { return alert("No device selected") }
        connect(to: sel)
    }

    func connect(to device: WearableDevice) {
        selectedDevice = device
        if let info = manager.devices.first(where: { $0.id == device.id }) {
            proceedConnect(info)
        } else {
            log("Device info not found, refreshing once…")
            manager.getAvailableDevicesWithRetry(retries: 1, delay: 0.5) { [weak self] infos, _ in
                guard let self else { return }
                if let refreshed = infos.first(where: { $0.id == device.id }) {
                    self.proceedConnect(refreshed)
                } else {
                    self.alert("Device not found after refresh")
                }
            }
        }
    }

    private func proceedConnect(_ info: WearEngineManager.WearableDeviceInfo) {
        manager.connectToDevice(info) { [weak self] ok, msg in
            guard let self else { return }
            guard ok else { return self.alert(msg) }
            let connected = WearableDevice(id: info.id, name: info.name, isConnected: true)
            self.selectedDevice = connected
            if let idx = self.devices.firstIndex(where: { $0.id == info.id }) {
                self.devices[idx] = connected
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.manager.registerMessageListener()
            }
        }
    }

    func sendMessage() {
        guard !currentMessage.isEmpty else { return alert("Please enter a message") }
        guard requireAuthorizedAndSelectedConnected() else { return }

        let text = currentMessage
        currentMessage = ""
        messages.append(.init(content: text, timestamp: Date(), isOutgoing: true))

        manager.sendMessage(text) { [weak self] ok, result in
            guard let self else { return }
            if ok {
                self.alert("Send message successful")
            } else {
                self.alert(result)
            }
        }
    }

    func sendLongMessage() {
        guard requireAuthorizedAndSelectedConnected() else { return }

        isLongSendInProgress = true
        isAlertManuallyDismissed = false
        alertMessage = "Sending long message… 0%"

        manager.sendLongMessage(
            size: 50 * 1024,
            progress: { [weak self] sent, total in
                guard let self else { return }
                let percent = Int((Double(sent) / Double(total)) * 100.0)
                print("PROGRESS \(sent)/\(total) -> \(percent)%")
                if self.isLongSendInProgress && !self.isAlertManuallyDismissed {
                    self.alertMessage = "Sending long message… \(percent)% (\(sent)/\(total))"
                }
            },
            completion: { [weak self] ok, result in
                guard let self else { return }
                if ok {
                    if self.isLongSendInProgress && !self.isAlertManuallyDismissed {
                        self.alertMessage = "Long message completed"
                    }
                } else {
                    self.isLongSendInProgress = false
                    self.alert(result)
                }
            }
        )
    }

    func pingDevice() {
        guard requireAuthorizedAndSelectedConnected() else { return }
        manager.pingDevice { [weak self] _, result in self?.alert(result) }
    }

    func checkAppInstallation() {
        guard requireAuthorizedAndSelectedConnected() else { return }
        manager.checkAppInstallation { [weak self] _, result in self?.alert(result) }
    }

    func getAppVersion() {
        guard requireAuthorizedAndSelectedConnected() else { return }
        manager.getAppVersion { [weak self] version, error in
            guard let self else { return }
            guard let version else { return self.alert(error ?? "Unknown error") }
            self.alert("App Version: \(version)")
        }
    }

    func clearLogs() {
        logs.removeAll()
        log("Logs cleared")
    }

    struct LogEntry: Identifiable, Hashable { let id = UUID(); let text: String }
    struct WearableDevice: Identifiable, Hashable { let id: String; let name: String; let isConnected: Bool }
    struct P2PMessage: Identifiable, Hashable { let id = UUID(); let content: String; let timestamp: Date; let isOutgoing: Bool }

    @discardableResult
    private func requireAuthorizedAndSelectedConnected() -> Bool {
        guard isAuthorized else { alert("Please authorize the app first"); return false }
        guard let sel = selectedDevice else { alert("Please select a device first"); return false }
        guard sel.isConnected else { alert("Please connect the selected device"); return false }
        return true
    }

    private func log(_ message: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.append(.init(text: "[\(ts)] \(message)"))
        if logs.count > 200 { logs.removeFirst() }
    }

    private func alert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
