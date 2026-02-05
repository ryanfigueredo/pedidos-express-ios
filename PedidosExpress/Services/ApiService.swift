import Foundation

class ApiService {
    private let baseURL = "https://pedidos.dmtn.com.br"
    
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
            print("❌ ApiService: URL inválida: \(url)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0 // 30 segundos de timeout
        
        // Basic Auth é obrigatório - o backend identifica o tenant pelo usuário autenticado
        guard let authHeader = getAuthHeader() else {
            print("⚠️ ApiService: Sem credenciais para Basic Auth")
            return nil
        }
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        
        // X-User-Id opcional (pode ajudar em logs)
        if let userId = getUserId() {
            request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        #if DEBUG
        print("🌐 ApiService: \(method) \(url)")
        if let userId = getUserId() {
            print("   User ID: \(userId)")
        }
        #endif
        
        return request
    }
    
    func login(username: String, password: String) async throws -> User {
        let url = "\(baseURL)/api/auth/mobile-login"
        let body = try encoder.encode(["username": username, "password": password])
        
        guard let request = buildRequest(url: url, method: "POST", body: body) else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            // Tentar endpoint alternativo
            let altUrl = "\(baseURL)/api/auth/login"
            guard let altRequest = buildRequest(url: altUrl, method: "POST", body: body) else {
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
            print("❌ ApiService.getAllOrders: Não foi possível criar requisição")
            throw ApiError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ ApiService.getAllOrders: Resposta inválida")
            throw ApiError.invalidResponse
        }
        
        #if DEBUG
        print("📦 ApiService.getAllOrders: Status \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Resposta: \(responseString.prefix(500))")
            }
        }
        #endif
        
        // O backend sempre retorna 200, mesmo em caso de erro (retorna array vazio)
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                print("❌ ApiService.getAllOrders: Não autorizado (401) - verifique credenciais")
            }
            // Retornar vazio em vez de erro
            let pagination = Pagination(page: page, limit: limit, total: 0, hasMore: false)
            return OrdersResponse(orders: [], pagination: pagination)
        }
        
        // Tentar decodificar diretamente primeiro
        if let response = try? decoder.decode(OrdersResponse.self, from: data) {
            return response
        }
        
        // Se falhar, tentar parsear manualmente
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Se não conseguir parsear JSON, retornar vazio
            let pagination = Pagination(page: page, limit: limit, total: 0, hasMore: false)
            return OrdersResponse(orders: [], pagination: pagination)
        }
        
        // Extrair orders
        var orders: [Order] = []
        if let ordersData = json["orders"] as? [[String: Any]] {
            for orderData in ordersData {
                do {
                    let orderJson = try JSONSerialization.data(withJSONObject: orderData)
                    let order = try decoder.decode(Order.self, from: orderJson)
                    orders.append(order)
                } catch {
                    // Ignorar pedidos que não conseguem ser decodificados
                    print("Erro ao decodificar pedido: \(error)")
                    continue
                }
            }
        }
        
        // Extrair pagination
        var pageNum = page
        var limitNum = limit
        var totalNum = orders.count
        var hasMore = false
        
        if let paginationData = json["pagination"] as? [String: Any] {
            pageNum = paginationData["page"] as? Int ?? page
            limitNum = paginationData["limit"] as? Int ?? limit
            totalNum = paginationData["total"] as? Int ?? orders.count
            // Backend retorna "hasMore" (camelCase), não "has_more"
            if let hasMoreValue = paginationData["hasMore"] as? Bool {
                hasMore = hasMoreValue
            } else if let hasMoreValue = paginationData["has_more"] as? Bool {
                hasMore = hasMoreValue
            } else {
                // Calcular hasMore baseado em skip + limit < total
                let skip = (pageNum - 1) * limitNum
                hasMore = skip + limitNum < totalNum
            }
        }
        
        let pagination = Pagination(page: pageNum, limit: limitNum, total: totalNum, hasMore: hasMore)
        return OrdersResponse(orders: orders, pagination: pagination)
        } catch let urlError as URLError {
            print("❌ ApiService.getAllOrders: Erro de rede - \(urlError.localizedDescription)")
            // Retornar vazio em caso de erro de rede
            let pagination = Pagination(page: page, limit: limit, total: 0, hasMore: false)
            return OrdersResponse(orders: [], pagination: pagination)
        } catch {
            print("❌ ApiService.getAllOrders: Erro desconhecido - \(error.localizedDescription)")
            // Retornar vazio em caso de erro
            let pagination = Pagination(page: page, limit: limit, total: 0, hasMore: false)
            return OrdersResponse(orders: [], pagination: pagination)
        }
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
            print("❌ ApiService.getStats: Não foi possível criar requisição")
            throw ApiError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ ApiService.getStats: Resposta inválida")
                throw ApiError.invalidResponse
            }
            
            #if DEBUG
            print("📊 ApiService.getStats: Status \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Resposta: \(responseString.prefix(1000))")
            }
            #endif
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    print("❌ ApiService.getStats: Não autorizado (401) - verifique credenciais")
                }
                throw ApiError.requestFailed
            }
            
            // Tentar decodificar diretamente primeiro
            if let statsResponse = try? decoder.decode(StatsResponse.self, from: data) {
                return statsResponse.stats
            }
            
            // Tentar parsear manualmente
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ ApiService.getStats: Não foi possível parsear JSON")
                throw ApiError.requestFailed
            }
            
            // Verificar se tem campo "success" e "stats"
            if let success = json["success"] as? Bool, success,
               let statsData = json["stats"] as? [String: Any] {
                let statsJson = try JSONSerialization.data(withJSONObject: statsData)
                return try decoder.decode(DashboardStats.self, from: statsJson)
            }
            
            // Se não tem "success", tentar decodificar diretamente como stats
            if let statsData = json as? [String: Any] {
                let statsJson = try JSONSerialization.data(withJSONObject: statsData)
                return try decoder.decode(DashboardStats.self, from: statsJson)
            }
            
            print("❌ ApiService.getStats: Formato de resposta inesperado")
            throw ApiError.requestFailed
        } catch let urlError as URLError {
            print("❌ ApiService.getStats: Erro de rede - \(urlError.localizedDescription)")
            throw ApiError.requestFailed
        } catch let decodingError as DecodingError {
            print("❌ ApiService.getStats: Erro ao decodificar - \(decodingError)")
            throw ApiError.requestFailed
        } catch {
            print("❌ ApiService.getStats: Erro desconhecido - \(error.localizedDescription)")
            throw error
        }
    }
    
    // Helper struct para decodificar resposta da API
    private struct StatsResponse: Codable {
        let success: Bool?
        let stats: DashboardStats
    }
    
    func getMenu() async throws -> [MenuItem] {
        let url = "\(baseURL)/api/admin/menu"
        
        guard let request = buildRequest(url: url, method: "GET") else {
            print("❌ ApiService.getMenu: Não foi possível criar requisição")
            throw ApiError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ ApiService.getMenu: Resposta inválida")
            throw ApiError.invalidResponse
        }
        
        #if DEBUG
        print("📋 ApiService.getMenu: Status \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Resposta: \(responseString.prefix(500))")
            }
        }
        #endif
        
        // O backend sempre retorna 200, mesmo em caso de erro (retorna array vazio)
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                print("❌ ApiService.getMenu: Não autorizado (401) - verifique credenciais")
            }
            // Retornar vazio em vez de erro
            return []
        }
        
        // Tentar decodificar diretamente primeiro (se items vier como array direto)
        if let items = try? decoder.decode([MenuItem].self, from: data) {
            return items
        }
        
        // Tentar parsear como objeto com campo "items"
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Se não conseguir parsear JSON, retornar vazio
            return []
        }
        
        // Extrair items
        var menuItems: [MenuItem] = []
        if let itemsData = json["items"] as? [[String: Any]] {
            for itemData in itemsData {
                do {
                    let itemJson = try JSONSerialization.data(withJSONObject: itemData)
                    let item = try decoder.decode(MenuItem.self, from: itemJson)
                    menuItems.append(item)
                } catch {
                    // Ignorar itens que não conseguem ser decodificados
                    print("Erro ao decodificar item do menu: \(error)")
                    continue
                }
            }
        }
        
        return menuItems
        } catch let urlError as URLError {
            print("❌ ApiService.getMenu: Erro de rede - \(urlError.localizedDescription)")
            return []
        } catch {
            print("❌ ApiService.getMenu: Erro desconhecido - \(error.localizedDescription)")
            return []
        }
    }
    
    func createMenuItem(id: String, name: String, price: Double, category: String, available: Bool = true) async throws -> MenuItem {
        let url = "\(baseURL)/api/admin/menu"
        let bodyDict: [String: Any] = [
            "id": id,
            "name": name,
            "price": price,
            "category": category,
            "available": available
        ]
        let body = try JSONSerialization.data(withJSONObject: bodyDict)
        
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
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.invalidResponse
        }
        
        // Se não houver dados ou status diferente de 200, retornar array vazio
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                return [] // Endpoint não encontrado, retornar vazio
            }
            throw ApiError.requestFailed
        }
        
        // Tentar parsear como array direto primeiro
        if let conversationsArray = try? decoder.decode([PriorityConversation].self, from: data) {
            return conversationsArray
        }
        
        // Tentar parsear como objeto com campo "conversations"
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let conversationsData = json["conversations"] as? [[String: Any]] {
                let conversationsJson = try JSONSerialization.data(withJSONObject: conversationsData)
                return try decoder.decode([PriorityConversation].self, from: conversationsJson)
            }
            // Se não tiver campo "conversations", retornar vazio
            return []
        }
        
        // Se não conseguir parsear, retornar array vazio
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
    
    func getSubscription() async throws -> Subscription? {
        let url = "\(baseURL)/api/admin/subscription"
        
        guard let request = buildRequest(url: url, method: "GET") else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ApiError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let subscriptionData = json["subscription"] as? [String: Any] {
            let subscriptionJson = try JSONSerialization.data(withJSONObject: subscriptionData)
            return try decoder.decode(Subscription.self, from: subscriptionJson)
        }
        
        return nil
    }
}

enum ApiError: Error {
    case invalidURL
    case invalidResponse
    case loginFailed
    case requestFailed
}
