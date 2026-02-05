import Foundation

struct Subscription: Codable {
    let planType: String
    let planName: String
    let planMessageLimit: Int
    let paymentDate: String?
    let expiresAt: String?
    let status: String
    let daysUntilExpiration: Int?
    let isExpired: Bool
    let isExpiringSoon: Bool
    let paymentUrl: String
    let asaasSubscriptionId: String?
    let asaasCustomerId: String?
    
    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case planName = "plan_name"
        case planMessageLimit = "plan_message_limit"
        case paymentDate = "payment_date"
        case expiresAt = "expires_at"
        case status
        case daysUntilExpiration = "days_until_expiration"
        case isExpired = "is_expired"
        case isExpiringSoon = "is_expiring_soon"
        case paymentUrl = "payment_url"
        case asaasSubscriptionId = "asaas_subscription_id"
        case asaasCustomerId = "asaas_customer_id"
    }
}
