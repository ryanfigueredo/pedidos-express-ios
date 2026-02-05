import Foundation

class ApiService {
    private let baseURL = "https://pedidos.dmtn.com.br"
    private let apiKey = "tamboril-burguer-api-key-2024-secure"
    private let tenantId = "tamboril-burguer"
    
    private let authService = AuthService()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    private func getAuthHeader() -> String? {
        guard let credentials = authService.getCredentials() else {
            return nil
        }
        let credentialsString = "\(credentials.username):\(credentials.password)"
        guard let credentialsData = credentialsString.data(using: .utf8) else {
            return nil
        }
        let encoded = credentialsData.base64EncodedString()
        return "Basic \(encoded)"
    }
    
    private func getUserId() -> String? {
        return authService.getUser()?.id
    }
    
    private func buildRequest(url: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let url = URL(string: url) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue(tenantId, forHTTPHeaderField: "X-Tenant-Id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authHeader = getAuthHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        if let userId = getUserId() {
            request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    func login(username: String, password: String) async throws -> User {
        let url = "\(baseURL)/api/auth/mobile-login"
        let body = try encoder.encode(["username": username, "password": password])
        
        guard var request = buildRequest(url: url, method: "POST", body: body) else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            // Tentar endpoint alternativo
            let altUrl = "\(baseURL)/api/auth/login"
            guard var altRequest = buildRequest(url: altUrl, method: "POST", body: body) else {
                throw ApiError.invalidURL
            }
            
            let (altData, altResponse) = try await URLSession.shared.data(for: altRequest)
            
            guard let altHttpResponse = altResponse as? HTTPURLResponse,
                  altHttpResponse.statusCode == 200 else {
                throw ApiError.loginFailed
            }
            
            if let json = try JSONSerialization.jsonObject(with: altData) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let userData = json["user"] as? [String: Any] {
                let userJson = try JSONSerialization.data(withJSONObject: userData)
                return try decoder.decode(User.self, from: userJson)
            }
            
            throw ApiError.loginFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ApiError.loginFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool, success,
           let userData = json["user"] as? [String: Any] {
            let userJson = try JSONSerialization.data(withJSONObject: userData)
            return try decoder.decode(User.self, from: userJson)
        }
        
        throw ApiError.loginFailed
    }
    
    func getAllOrders(page: Int = 1, limit: Int = 20) async throws -> OrdersResponse {
        let url = "\(baseURL)/api/orders?page=\(page)&limit=\(limit)"
        
        guard let request = buildRequest(url: url, method: "GET") else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
        
        return try decoder.decode(OrdersResponse.self, from: data)
    }
    
    func updateOrderStatus(orderId: String, status: String) async throws {
        let url = "\(baseURL)/api/orders/\(orderId)/status"
        let body = try encoder.encode(["status": status])
        
        guard let request = buildRequest(url: url, method: "PATCH", body: body) else {
            throw ApiError.invalidURL
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
    }
    
    func sendMessageToCustomer(phone: String, message: String) async throws {
        let url = "\(baseURL)/api/bot/send-message"
        let body = try encoder.encode(["phone": phone, "message": message])
        
        guard let request = buildRequest(url: url, method: "POST", body: body) else {
            throw ApiError.invalidURL
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
    }
    
    func updateOrder(orderId: String, items: [OrderItem]) async throws {
        let url = "\(baseURL)/api/orders/\(orderId)"
        let body = try encoder.encode(["items": items])
        
        guard let request = buildRequest(url: url, method: "PATCH", body: body) else {
            throw ApiError.invalidURL
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
    }
    
    func getOrderById(orderId: String) async throws -> Order {
        // Primeiro tentar buscar da lista completa
        let allOrders = try await getAllOrders(page: 1, limit: 100)
        if let foundOrder = allOrders.orders.first(where: { $0.id == orderId }) {
            return foundOrder
        }
        
        // Se não encontrou, buscar individualmente
        let url = "\(baseURL)/api/orders/\(orderId)"
        
        guard let request = buildRequest(url: url, method: "GET") else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let orderData = json["order"] as? [String: Any] {
            let orderJson = try JSONSerialization.data(withJSONObject: orderData)
            return try decoder.decode(Order.self, from: orderJson)
        }
        
        throw ApiError.requestFailed
    }
    
    func getStats() async throws -> DashboardStats {
        let url = "\(baseURL)/api/admin/stats"
        
        guard let request = buildRequest(url: url, method: "GET") else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let statsData = json["stats"] as? [String: Any] {
            let statsJson = try JSONSerialization.data(withJSONObject: statsData)
            return try decoder.decode(DashboardStats.self, from: statsJson)
        }
        
        throw ApiError.requestFailed
    }
    
    func getMenu() async throws -> [MenuItem] {
        let url = "\(baseURL)/api/admin/menu"
        
        guard let request = buildRequest(url: url, method: "GET") else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let itemsData = json["items"] as? [[String: Any]] {
            let itemsJson = try JSONSerialization.data(withJSONObject: itemsData)
            return try decoder.decode([MenuItem].self, from: itemsJson)
        }
        
        throw ApiError.requestFailed
    }
    
    func createMenuItem(id: String, name: String, price: Double, category: String, available: Bool = true) async throws -> MenuItem {
        let url = "\(baseURL)/api/admin/menu"
        let body = try encoder.encode([
            "id": id,
            "name": name,
            "price": price,
            "category": category,
            "available": available
        ])
        
        guard let request = buildRequest(url: url, method: "POST", body: body) else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let itemData = json["item"] as? [String: Any] {
            let itemJson = try JSONSerialization.data(withJSONObject: itemData)
            return try decoder.decode(MenuItem.self, from: itemJson)
        }
        
        throw ApiError.requestFailed
    }
    
    func updateMenuItem(id: String, name: String? = nil, price: Double? = nil, category: String? = nil, available: Bool? = nil) async throws -> MenuItem {
        let url = "\(baseURL)/api/admin/menu"
        var bodyDict: [String: Any] = ["id": id]
        if let name = name { bodyDict["name"] = name }
        if let price = price { bodyDict["price"] = price }
        if let category = category { bodyDict["category"] = category }
        if let available = available { bodyDict["available"] = available }
        
        let body = try JSONSerialization.data(withJSONObject: bodyDict)
        
        guard let request = buildRequest(url: url, method: "PUT", body: body) else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let itemData = json["item"] as? [String: Any] {
            let itemJson = try JSONSerialization.data(withJSONObject: itemData)
            return try decoder.decode(MenuItem.self, from: itemJson)
        }
        
        throw ApiError.requestFailed
    }
    
    func deleteMenuItem(id: String) async throws -> Bool {
        let url = "\(baseURL)/api/admin/menu?id=\(id)"
        
        guard let request = buildRequest(url: url, method: "DELETE") else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            return success
        }
        
        return false
    }
    
    func getStoreStatus() async throws -> StoreStatus {
        let url = "\(baseURL)/api/admin/store-hours"
        
        guard let request = buildRequest(url: url, method: "GET") else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
        
        return try decoder.decode(StoreStatus.self, from: data)
    }
    
    func updateStoreStatus(isOpen: Bool) async throws {
        let url = "\(baseURL)/api/admin/store-hours"
        let body = try encoder.encode(["isOpen": isOpen])
        
        guard let request = buildRequest(url: url, method: "POST", body: body) else {
            throw ApiError.invalidURL
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
    }
    
    func getPriorityConversations() async throws -> [PriorityConversation] {
        let url = "\(baseURL)/api/admin/priority-conversations"
        
        guard let request = buildRequest(url: url, method: "GET") else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let conversationsData = json["conversations"] as? [[String: Any]] {
            let conversationsJson = try JSONSerialization.data(withJSONObject: conversationsData)
            return try decoder.decode([PriorityConversation].self, from: conversationsJson)
        }
        
        return []
    }
    
    func sendWhatsAppMessage(phone: String, message: String) async throws -> Bool {
        let url = "\(baseURL)/api/admin/send-whatsapp"
        let body = try encoder.encode(["phone": phone, "message": message])
        
        guard let request = buildRequest(url: url, method: "POST", body: body) else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            return success
        }
        
        return false
    }
}

enum ApiError: Error {
    case invalidURL
    case invalidResponse
    case loginFailed
    case requestFailed
}
