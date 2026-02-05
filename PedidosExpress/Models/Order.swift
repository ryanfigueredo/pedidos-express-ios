import Foundation

struct Order: Codable {
    let id: String
    let customerName: String
    let customerPhone: String
    let items: [OrderItem]
    let totalPrice: Double
    let status: String // "pending" | "printed" | "finished" | "out_for_delivery"
    let createdAt: String
    let displayId: String?
    let dailySequence: Int?
    let orderType: String?
    let deliveryAddress: String?
    let paymentMethod: String?
    let subtotal: Double?
    let deliveryFee: Double?
    let changeFor: Double?
    let printRequestedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case customerName = "customer_name"
        case customerPhone = "customer_phone"
        case items
        case totalPrice = "total_price"
        case status
        case createdAt = "created_at"
        case displayId = "display_id"
        case dailySequence = "daily_sequence"
        case orderType = "order_type"
        case deliveryAddress = "delivery_address"
        case paymentMethod = "payment_method"
        case subtotal
        case deliveryFee = "delivery_fee"
        case changeFor = "change_for"
        case printRequestedAt = "print_requested_at"
    }
}

struct OrderItem: Codable {
    let name: String
    let quantity: Int
    let price: Double
}

struct OrdersResponse: Codable {
    let orders: [Order]
    let pagination: Pagination
}

struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case page
        case limit
        case total
        case hasMore = "has_more"
    }
}
