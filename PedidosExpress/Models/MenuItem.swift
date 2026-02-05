import Foundation

struct MenuItem: Codable {
    let id: String
    let name: String
    let price: Double
    let category: String
    let available: Bool
}
