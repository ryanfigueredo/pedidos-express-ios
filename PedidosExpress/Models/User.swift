import Foundation

struct User: Codable {
    let id: String
    let username: String
    let name: String
    let role: String
    let tenantId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case name
        case role
        case tenantId = "tenant_id"
    }
}
