import Foundation

struct User: Codable {
    let id: String
    let username: String
    let name: String
    let role: String
    let tenantId: String?
    let businessType: String?
    let showPricesOnBot: Bool?
    let tenantName: String?
    let tenantSlug: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case name
        case role
        case tenantId = "tenant_id"
        case businessType = "business_type"
        case showPricesOnBot = "show_prices_on_bot"
        case tenantName = "tenant_name"
        case tenantSlug = "tenant_slug"
    }
    
    var isDentista: Bool {
        return businessType == "DENTISTA"
    }
    
    var isRestaurante: Bool {
        return businessType == "RESTAURANTE" || businessType == nil
    }
}
