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
        case phoneFormatted = "phone_formatted"
        case whatsappUrl = "whatsapp_url"
        case waitTime = "wait_time"
        case timestamp
        case lastMessage = "last_message"
    }
}
