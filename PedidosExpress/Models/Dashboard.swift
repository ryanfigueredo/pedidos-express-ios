import Foundation

struct DashboardStats: Codable {
    let today: DayStats
    let week: WeekStats
    let pendingOrders: Int
    let dailyStats: [DailyStat]
    
    enum CodingKeys: String, CodingKey {
        case today
        case week
        case pendingOrders = "pendingOrders"
        case dailyStats = "dailyStats"
    }
}

struct DayStats: Codable {
    let orders: Int
    let revenue: Double
}

struct WeekStats: Codable {
    let orders: Int
    let revenue: Double
}

struct DailyStat: Codable {
    let day: String
    let orders: Int
    let revenue: Double
}

struct StoreStatus: Codable {
    let isOpen: Bool
    let nextOpenTime: String?
    let message: String?
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case isOpen = "isOpen"
        case nextOpenTime = "nextOpenTime"
        case message
        case lastUpdated = "lastUpdated"
    }
}

struct PriorityConversation: Codable {
    let phone: String
    let phoneFormatted: String
    let whatsappUrl: String
    let waitTime: Int
    let timestamp: Int64
    let lastMessage: Int64
    
    enum CodingKeys: String, CodingKey {
        case phone
        case phoneFormatted
        case whatsappUrl
        case waitTime
        case timestamp
        case lastMessage
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        phone = try container.decode(String.self, forKey: .phone)
        
        // phoneFormatted - aceita String ou usa phone como fallback
        phoneFormatted = (try? container.decode(String.self, forKey: .phoneFormatted)) ?? phone
        
        // whatsappUrl - aceita String ou gera URL como fallback
        whatsappUrl = (try? container.decode(String.self, forKey: .whatsappUrl)) ?? "https://wa.me/\(phone)"
        
        // waitTime - aceita Int ou Double, default 0
        if let waitTimeInt = try? container.decode(Int.self, forKey: .waitTime) {
            waitTime = waitTimeInt
        } else if let waitTimeDouble = try? container.decode(Double.self, forKey: .waitTime) {
            waitTime = Int(waitTimeDouble)
        } else {
            waitTime = 0
        }
        
        // timestamp - aceita Int64, Int ou Double, default agora
        if let timestampValue = try? container.decode(Int64.self, forKey: .timestamp) {
            timestamp = timestampValue
        } else if let timestampInt = try? container.decode(Int.self, forKey: .timestamp) {
            timestamp = Int64(timestampInt)
        } else if let timestampDouble = try? container.decode(Double.self, forKey: .timestamp) {
            timestamp = Int64(timestampDouble)
        } else {
            timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        }
        
        // lastMessage - aceita Int64, Int ou Double, default timestamp
        if let lastMessageValue = try? container.decode(Int64.self, forKey: .lastMessage) {
            lastMessage = lastMessageValue
        } else if let lastMessageInt = try? container.decode(Int.self, forKey: .lastMessage) {
            lastMessage = Int64(lastMessageInt)
        } else if let lastMessageDouble = try? container.decode(Double.self, forKey: .lastMessage) {
            lastMessage = Int64(lastMessageDouble)
        } else {
            lastMessage = timestamp
        }
    }
}
