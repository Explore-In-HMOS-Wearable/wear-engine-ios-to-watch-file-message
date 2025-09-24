import Foundation

struct WearableDevice: Identifiable, Hashable {
    let id: String // uuid string (cihazın uuid’si)
    let name: String
    let isConnected: Bool
}

struct P2PMessage: Identifiable {
    let id = UUID() // Wearable device UDID
    let content: String
    let timestamp: Date
    let isOutgoing: Bool
}
