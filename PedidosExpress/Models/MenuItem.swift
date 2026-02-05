import Foundation

struct MenuItem: Codable {
    let id: String
    let name: String
    let price: Double
    let category: String
    let available: Bool
    let order: Int? // Campo opcional do backend
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case price
        case category
        case available
        case order
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // price pode vir como Double ou Number
        if let priceDouble = try? container.decode(Double.self, forKey: .price) {
            price = priceDouble
        } else if let priceInt = try? container.decode(Int.self, forKey: .price) {
            price = Double(priceInt)
        } else {
            price = 0.0
        }
        
        category = try container.decode(String.self, forKey: .category)
        available = try container.decode(Bool.self, forKey: .available)
        order = try? container.decode(Int.self, forKey: .order)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(price, forKey: .price)
        try container.encode(category, forKey: .category)
        try container.encode(available, forKey: .available)
        try container.encodeIfPresent(order, forKey: .order)
    }
}
