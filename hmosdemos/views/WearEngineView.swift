import SwiftUI

struct WearEngineView: View {
    @StateObject private var vm = WearEngineViewModel()
    @State private var messageText = ""

    var body: some View {   
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    authorizationSection
                    devicesSection
                    p2pSection
                    utilitiesSection
                    receivedSection
                    logsSection
                }
                .padding(12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Wear Engine - iOS to Wearable \nSend Message & Long Messager Sample")
                            .font(.system(size: 16, weight: .semibold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .alert("Info", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {
                vm.isAlertManuallyDismissed = true
            }
        } message: {
            Text(vm.alertMessage)
        }
        .overlay(alignment: .center) {
            if vm.isLongSendInProgress && !vm.isAlertManuallyDismissed {
                VStack(spacing: 12) {
                    Text("Info")
                        .font(.headline)
                    Text(vm.alertMessage)
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                    Button("OK") {
                        vm.isAlertManuallyDismissed = true
                        vm.isLongSendInProgress = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(radius: 8)
                .frame(maxWidth: 280)
            }
        }
    }

    private var authorizationSection: some View {
        section("Authorization") {
            HStack(spacing: 10) {
                Circle()
                    .fill(vm.isAuthorized ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text(vm.isAuthorized ? "Authorized" : "Not Authorized")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(vm.isAuthorized ? .green : .red)

                Spacer()

                Button("Authorize", action: vm.requestAuthorization)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var devicesSection: some View {
        section("Devices") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("Refresh devices", action: vm.loadDevices)
                        .buttonStyle(.bordered)

                    Button("Connect selected", action: vm.connectSelectedIfAny)
                        .buttonStyle(.borderedProminent)
                }

                if vm.devices.isEmpty {
                    Text("No devices available")
                        .foregroundColor(.secondary)
                } else {
                    deviceList
                }
            }
        }
    }

    private var deviceList: some View {
        VStack(spacing: 6) {
            ForEach(vm.devices) { d in
                Button {
                    vm.selectedDevice = d
                } label: {
                    HStack {
                        Image(systemName: vm.selectedDevice?.id == d.id ? "largecircle.fill.circle" : "circle")
                        Text(d.name)
                        Spacer()
                        Text(d.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(d.isConnected ? .green : .secondary)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var p2pSection: some View {
        section("P2P") {
            HStack(spacing: 8) {
                TextField("Message...", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    vm.currentMessage = messageText
                    vm.sendMessage()
                }
                .buttonStyle(.borderedProminent)

                Button("Send 50KB", action: vm.sendLongMessage)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var utilitiesSection: some View {
        section("Utilities") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button("Ping", action: vm.pingDevice).buttonStyle(.bordered)
                    Button("Check App", action: vm.checkAppInstallation).buttonStyle(.bordered)
                    Button("Version", action: vm.getAppVersion).buttonStyle(.bordered)
                }
            }
        }
    }

    private var receivedSection: some View {
        section("Received Messages") {
            let incoming = vm.messages.filter { !$0.isOutgoing }
            if incoming.isEmpty {
                Text("No messages received").foregroundColor(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(incoming.suffix(5)) { m in
                        HStack {
                            Text(m.content)
                                .padding(8)
                                .background(Color.orange.opacity(0.7))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Spacer()
                            Text(
                                DateFormatter.localizedString(
                                    from: m.timestamp,
                                    dateStyle: .none,
                                    timeStyle: .short
                                )
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var logsSection: some View {
        section("Logs") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button("Clear", action: vm.clearLogs)
                        .buttonStyle(.bordered)
                    Spacer()
                }

                if vm.logs.isEmpty {
                    Text("No logs")
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(vm.logs.suffix(80))) { entry in
                            Text(entry.text)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 16, weight: .semibold))
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}
