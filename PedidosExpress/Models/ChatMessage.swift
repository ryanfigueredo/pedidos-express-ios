import Foundation

struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let isAttendant: Bool
    let timestamp: Date
    var status: MessageStatus
    
    enum MessageStatus {
        case sending
        case sent
        case error
    }
}
