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
    
    // Decoder customizado para lidar com campos faltantes ou tipos diferentes
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        
        // customerName pode não existir - usar valor padrão se não encontrar
        if let customerNameValue = try? container.decode(String.self, forKey: .customerName) {
            customerName = customerNameValue
        } else {
            customerName = "Cliente"
        }
        
        // customerPhone pode não existir - usar valor padrão se não encontrar
        if let customerPhoneValue = try? container.decode(String.self, forKey: .customerPhone) {
            customerPhone = customerPhoneValue
        } else {
            customerPhone = ""
        }
        
        items = try container.decode([OrderItem].self, forKey: .items)
        
        // totalPrice pode vir como Double, String, ou Int
        var decodedTotalPrice: Double = 0.0
        
        if let totalPriceDouble = try? container.decode(Double.self, forKey: .totalPrice) {
            decodedTotalPrice = totalPriceDouble
            #if DEBUG
            print("   💰 totalPrice decodificado como Double: \(totalPriceDouble)")
            #endif
        } else if let totalPriceInt = try? container.decode(Int.self, forKey: .totalPrice) {
            decodedTotalPrice = Double(totalPriceInt)
            #if DEBUG
            print("   💰 totalPrice decodificado como Int: \(totalPriceInt) -> \(decodedTotalPrice)")
            #endif
        } else if let totalPriceString = try? container.decode(String.self, forKey: .totalPrice) {
            // Tentar converter string para double
            if let totalPriceDouble = Double(totalPriceString) {
                decodedTotalPrice = totalPriceDouble
                #if DEBUG
                print("   💰 totalPrice decodificado como String: '\(totalPriceString)' -> \(totalPriceDouble)")
                #endif
            } else {
                // Se falhar, tentar remover caracteres não numéricos
                let cleaned = totalPriceString.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
                    .replacingOccurrences(of: ",", with: ".")
                if let totalPriceDouble = Double(cleaned) {
                    decodedTotalPrice = totalPriceDouble
                    #if DEBUG
                    print("   💰 totalPrice limpo e convertido: '\(totalPriceString)' -> '\(cleaned)' -> \(totalPriceDouble)")
                    #endif
                } else {
                    #if DEBUG
                    print("   ⚠️ totalPrice não pôde ser convertido de '\(totalPriceString)'")
                    #endif
                }
            }
        } else {
            #if DEBUG
            print("   ⚠️ totalPrice não encontrado ou null")
            #endif
        }
        
        // Se o total decodificado for 0 ou inválido, calcular a partir dos itens
        if decodedTotalPrice <= 0 && !items.isEmpty {
            let calculatedTotal = items.reduce(0.0) { $0 + (Double($1.quantity) * $1.price) }
            totalPrice = calculatedTotal
            #if DEBUG
            print("   💰 totalPrice calculado a partir dos itens: \(calculatedTotal)")
            #endif
        } else {
            totalPrice = decodedTotalPrice
        }
        
        status = try container.decode(String.self, forKey: .status)
        
        // createdAt pode vir como String, null, ou número (timestamp)
        // Usar decodeIfPresent para lidar com valores null
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = createdAtString
        } else if let createdAtTimestamp = try container.decodeIfPresent(Double.self, forKey: .createdAt) {
            // Se vier como timestamp numérico, converter para ISO string
            let date = Date(timeIntervalSince1970: createdAtTimestamp / 1000.0) // Assumir milissegundos
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.string(from: date)
        } else {
            // Valor é null ou não existe - usar data atual como fallback
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.string(from: Date())
        }
        
        // Campos opcionais
        displayId = try? container.decode(String.self, forKey: .displayId)
        dailySequence = try? container.decode(Int.self, forKey: .dailySequence)
        orderType = try? container.decode(String.self, forKey: .orderType)
        deliveryAddress = try? container.decode(String.self, forKey: .deliveryAddress)
        paymentMethod = try? container.decode(String.self, forKey: .paymentMethod)
        printRequestedAt = try? container.decode(String.self, forKey: .printRequestedAt)
        
        // Campos numéricos opcionais
        if let subtotalValue = try? container.decode(Double.self, forKey: .subtotal) {
            subtotal = subtotalValue
        } else if let subtotalString = try? container.decode(String.self, forKey: .subtotal),
                   let subtotalValue = Double(subtotalString) {
            subtotal = subtotalValue
        } else {
            subtotal = nil
        }
        
        if let deliveryFeeValue = try? container.decode(Double.self, forKey: .deliveryFee) {
            deliveryFee = deliveryFeeValue
        } else if let deliveryFeeString = try? container.decode(String.self, forKey: .deliveryFee),
                  let deliveryFeeValue = Double(deliveryFeeString) {
            deliveryFee = deliveryFeeValue
        } else {
            deliveryFee = nil
        }
        
        if let changeForValue = try? container.decode(Double.self, forKey: .changeFor) {
            changeFor = changeForValue
        } else if let changeForString = try? container.decode(String.self, forKey: .changeFor),
                  let changeForValue = Double(changeForString) {
            changeFor = changeForValue
        } else {
            changeFor = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(customerName, forKey: .customerName)
        try container.encode(customerPhone, forKey: .customerPhone)
        try container.encode(items, forKey: .items)
        try container.encode(totalPrice, forKey: .totalPrice)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(displayId, forKey: .displayId)
        try container.encodeIfPresent(dailySequence, forKey: .dailySequence)
        try container.encodeIfPresent(orderType, forKey: .orderType)
        try container.encodeIfPresent(deliveryAddress, forKey: .deliveryAddress)
        try container.encodeIfPresent(paymentMethod, forKey: .paymentMethod)
        try container.encodeIfPresent(subtotal, forKey: .subtotal)
        try container.encodeIfPresent(deliveryFee, forKey: .deliveryFee)
        try container.encodeIfPresent(changeFor, forKey: .changeFor)
        try container.encodeIfPresent(printRequestedAt, forKey: .printRequestedAt)
    }
}

struct OrderItem: Codable {
    let id: String?
    let name: String
    let quantity: Int
    let price: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case price
    }
    
    // Inicializador memberwise explícito
    init(id: String?, name: String, quantity: Int, price: Double) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.price = price
    }
    
    // Permitir que id seja opcional (pode não vir do backend)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // quantity pode vir como Int ou Double
        if let quantityInt = try? container.decode(Int.self, forKey: .quantity) {
            quantity = quantityInt
        } else if let quantityDouble = try? container.decode(Double.self, forKey: .quantity) {
            quantity = Int(quantityDouble)
        } else if let quantityString = try? container.decode(String.self, forKey: .quantity),
                  let quantityInt = Int(quantityString) {
            quantity = quantityInt
        } else {
            quantity = 1 // Valor padrão
        }
        
        // price pode vir como Double ou String
        if let priceDouble = try? container.decode(Double.self, forKey: .price) {
            price = priceDouble
        } else if let priceString = try? container.decode(String.self, forKey: .price),
                  let priceDouble = Double(priceString) {
            price = priceDouble
        } else {
            price = 0.0 // Valor padrão
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(price, forKey: .price)
    }
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
        case hasMore
        case has_more
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decode(Int.self, forKey: .page)
        limit = try container.decode(Int.self, forKey: .limit)
        total = try container.decode(Int.self, forKey: .total)
        
        // Aceitar tanto "hasMore" quanto "has_more"
        if let hasMoreValue = try? container.decode(Bool.self, forKey: .hasMore) {
            hasMore = hasMoreValue
        } else if let hasMoreValue = try? container.decode(Bool.self, forKey: .has_more) {
            hasMore = hasMoreValue
        } else {
            hasMore = false
        }
    }
    
    init(page: Int, limit: Int, total: Int, hasMore: Bool) {
        self.page = page
        self.limit = limit
        self.total = total
        self.hasMore = hasMore
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(page, forKey: .page)
        try container.encode(limit, forKey: .limit)
        try container.encode(total, forKey: .total)
        // Codificar como "hasMore" (camelCase)
        try container.encode(hasMore, forKey: .hasMore)
    }
}
