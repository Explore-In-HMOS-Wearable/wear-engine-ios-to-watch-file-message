import SwiftUI

private extension Color {
    static let cardShadow = Color.black.opacity(0.08)
    static let chipBackground = Color.gray.opacity(0.03)
    static let incomingBubble = Color.gray.opacity(0.3)
    static let receivedAccent = Color.orange.opacity(0.7)
}

private extension Font {
    static var deviceName: Font { .system(size: 13, weight: .medium) }
    static var deviceState: Font { .system(size: 10) }
    static var bubbleText: Font { .system(size: 11) }
    static var bubbleTime: Font { .system(size: 8) }
}

private enum BubbleRole {
    case outgoing
    case incoming

    var alignment: HorizontalAlignment { self == .outgoing ? .trailing : .leading }
    var background: Color { self == .outgoing ? .blue : .incomingBubble }
    var foreground: Color { self == .outgoing ? .white : .primary }
    var spacerPlacement: (leading: Bool, trailing: Bool) {
        self == .outgoing ? (true, false) : (false, true)
    }
}

private func shortTime(_ date: Date) -> String {
    DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
}

struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .cardShadow, radius: 4, x: 0, y: 1)
    }
}

struct DeviceRowView: View {
    let device: WearableDevice
    let onTap: () -> Void

    private var statusText: String {
        device.isConnected ? "Connected" : "Disconnected"
    }

    private var statusColor: Color {
        device.isConnected ? .green : .secondary
    }

    private var dotColor: Color {
        device.isConnected ? .green : .gray
    }

    @ViewBuilder
    private var trailingIcon: some View {
        if device.isConnected {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 12))
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name)
                        .font(.deviceName)
                        .foregroundColor(.primary)

                    HStack(spacing: 3) {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 6, height: 6)

                        Text(statusText)
                            .font(.deviceState)
                            .foregroundColor(statusColor)
                    }
                }

                Spacer()
                trailingIcon
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ChatBubble: View {
    let message: P2PMessage

    private var role: BubbleRole {
        message.isOutgoing ? .outgoing : .incoming
    }

    var body: some View {
        HStack {
            if role.spacerPlacement.leading { Spacer() }

            VStack(alignment: role.alignment, spacing: 1) {
                Text(message.content)
                    .font(.bubbleText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(role.background)
                    .foregroundColor(role.foreground)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(shortTime(message.timestamp))
                    .font(.bubbleTime)
                    .foregroundColor(.secondary)
            }

            if role.spacerPlacement.trailing { Spacer() }
        }
    }
}

struct ReceivedMessageBubbleView: View {
    let message: P2PMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(message.content)
                .font(.bubbleText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.receivedAccent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(shortTime(message.timestamp))
                .font(.bubbleTime)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
