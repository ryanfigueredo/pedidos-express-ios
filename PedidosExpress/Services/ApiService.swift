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
        let urlString = "\(baseURL)/api/auth/mobile-login"
        let body = try encoder.encode(["username": username, "password": password])
        
        #if DEBUG
        print("🔐 ApiService.login: Tentando fazer login para \(username)")
        print("🔐 ApiService.login: URL: \(urlString)")
        #endif
        
        // Para login, não usar buildRequest porque ainda não temos credenciais
        // Criar request diretamente sem Basic Auth
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("❌ ApiService.login: URL inválida: \(urlString)")
            #endif
            throw ApiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                print("❌ ApiService.login: Resposta inválida do servidor")
                #endif
                throw ApiError.invalidResponse
            }
            
            #if DEBUG
            print("🔐 ApiService.login: Status HTTP: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔐 ApiService.login: Resposta: \(responseString.prefix(200))")
            }
            #endif
            
            if httpResponse.statusCode == 404 {
                // Tentar endpoint alternativo
                #if DEBUG
                print("🔐 ApiService.login: Endpoint mobile-login não encontrado, tentando /api/auth/login")
                #endif
                let altUrlString = "\(baseURL)/api/auth/login"
                guard let altUrl = URL(string: altUrlString) else {
                    throw ApiError.invalidURL
                }
                
                var altRequest = URLRequest(url: altUrl)
                altRequest.httpMethod = "POST"
                altRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                altRequest.timeoutInterval = 30.0
                altRequest.httpBody = body
                
                let (altData, altResponse) = try await URLSession.shared.data(for: altRequest)
                
                guard let altHttpResponse = altResponse as? HTTPURLResponse else {
                    throw ApiError.invalidResponse
                }
                
                #if DEBUG
                print("🔐 ApiService.login: Status HTTP (alternativo): \(altHttpResponse.statusCode)")
                #endif
                
                guard altHttpResponse.statusCode == 200 else {
                    #if DEBUG
                    print("❌ ApiService.login: Login falhou - Status: \(altHttpResponse.statusCode)")
                    #endif
                    throw ApiError.loginFailed
                }
                
                if let json = try JSONSerialization.jsonObject(with: altData) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let userData = json["user"] as? [String: Any] {
                    let userJson = try JSONSerialization.data(withJSONObject: userData)
                    let user = try decoder.decode(User.self, from: userJson)
                    #if DEBUG
                    print("✅ ApiService.login: Login bem-sucedido!")
                    #endif
                    return user
                }
                
                throw ApiError.loginFailed
            }
            
            guard httpResponse.statusCode == 200 else {
                #if DEBUG
                print("❌ ApiService.login: Login falhou - Status: \(httpResponse.statusCode)")
                #endif
                throw ApiError.loginFailed
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let userData = json["user"] as? [String: Any] {
                let userJson = try JSONSerialization.data(withJSONObject: userData)
                let user = try decoder.decode(User.self, from: userJson)
                #if DEBUG
                print("✅ ApiService.login: Login bem-sucedido!")
                #endif
                return user
            }
            
            #if DEBUG
            print("❌ ApiService.login: Resposta não contém dados de usuário válidos")
            #endif
            throw ApiError.loginFailed
        } catch let error as ApiError {
            #if DEBUG
            print("❌ ApiService.login: ApiError - \(error.localizedDescription)")
            #endif
            throw error
        } catch {
            #if DEBUG
            print("❌ ApiService.login: Erro inesperado - \(error.localizedDescription)")
            print("❌ ApiService.login: Tipo do erro: \(type(of: error))")
            #endif
            // Se for erro de conexão, converter para ApiError.requestFailed
            if (error as NSError).code == NSURLErrorNotConnectedToInternet ||
               (error as NSError).code == NSURLErrorTimedOut ||
               (error as NSError).code == NSURLErrorCannotConnectToHost {
                throw ApiError.requestFailed
            }
            throw error
        }
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
            #if DEBUG
            print("📦 ApiService.getAllOrders: Encontrados \(ordersData.count) pedidos na resposta")
            if let firstOrder = ordersData.first {
                print("   Primeiro pedido (campos): \(firstOrder.keys.joined(separator: ", "))")
            }
            #endif
            
            for orderData in ordersData {
                do {
                    // Log dos valores importantes antes de decodificar
                    #if DEBUG
                    if let createdAtValue = orderData["created_at"] {
                        let valueType = type(of: createdAtValue)
                        let isNSNull = createdAtValue is NSNull
                        print("   🔍 created_at tipo: \(valueType), é NSNull: \(isNSNull), valor: \(createdAtValue)")
                    } else {
                        print("   ⚠️ created_at é nil ou não existe no dicionário")
                    }
                    
                    if let totalPriceValue = orderData["total_price"] {
                        let valueType = type(of: totalPriceValue)
                        let isNSNull = totalPriceValue is NSNull
                        print("   💰 total_price tipo: \(valueType), é NSNull: \(isNSNull), valor: \(totalPriceValue)")
                    } else {
                        print("   ⚠️ total_price é nil ou não existe no dicionário")
                    }
                    #endif
                    
                    // Garantir que created_at sempre tenha um valor válido
                    var sanitizedOrderData = orderData
                    if sanitizedOrderData["created_at"] == nil || sanitizedOrderData["created_at"] is NSNull {
                        // Se created_at não existe ou é null, usar data atual
                        let formatter = ISO8601DateFormatter()
                        sanitizedOrderData["created_at"] = formatter.string(from: Date())
                        #if DEBUG
                        print("   🔧 created_at era null/nil, substituído por data atual")
                        #endif
                    }
                    
                    // Converter NSNull para valores apropriados
                    for (key, value) in sanitizedOrderData {
                        if value is NSNull {
                            // Para created_at, já tratamos acima. Para outros campos, manter null
                            if key != "created_at" {
                                sanitizedOrderData[key] = nil
                            }
                        }
                    }
                    
                    // Serializar para JSON
                    let orderJson = try JSONSerialization.data(
                        withJSONObject: sanitizedOrderData,
                        options: []
                    )
                    
                    #if DEBUG
                    if let jsonString = String(data: orderJson, encoding: .utf8) {
                        let preview = String(jsonString.prefix(500))
                        print("   📄 JSON gerado (primeiros 500 chars): \(preview)")
                        // Verificar se created_at está no JSON
                        if jsonString.contains("\"created_at\"") {
                            print("   ✅ created_at encontrado no JSON")
                        } else {
                            print("   ❌ created_at NÃO encontrado no JSON!")
                        }
                    }
                    #endif
                    
                    let order = try decoder.decode(Order.self, from: orderJson)
                    orders.append(order)
                } catch {
                    // Log mais detalhado do erro
                    #if DEBUG
                    print("❌ Erro ao decodificar pedido: \(error)")
                    if let orderId = orderData["id"] as? String {
                        print("   ID do pedido: \(orderId)")
                    }
                    print("   Campos disponíveis: \(orderData.keys.joined(separator: ", "))")
                    if let createdAtValue = orderData["created_at"] {
                        print("   created_at tipo: \(type(of: createdAtValue)), valor: \(createdAtValue)")
                    } else {
                        print("   ⚠️ created_at é nil ou não existe")
                    }
                    #endif
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
                #if DEBUG
                print("📊 ApiService.getStats: Decodificando stats do campo 'stats'")
                if let todayData = statsData["today"] as? [String: Any] {
                    print("   today: orders=\(todayData["orders"] ?? "nil"), revenue=\(todayData["revenue"] ?? "nil")")
                }
                if let weekData = statsData["week"] as? [String: Any] {
                    print("   week: orders=\(weekData["orders"] ?? "nil"), revenue=\(weekData["revenue"] ?? "nil")")
                }
                #endif
                let statsJson = try JSONSerialization.data(withJSONObject: statsData)
                let decodedStats = try decoder.decode(DashboardStats.self, from: statsJson)
                #if DEBUG
                print("📊 ApiService.getStats: Stats decodificados - today.revenue=\(decodedStats.today.revenue), week.revenue=\(decodedStats.week.revenue)")
                #endif
                return decodedStats
            }
            
            // Se não tem "success", tentar decodificar diretamente como stats
            if let statsData = json as? [String: Any] {
                #if DEBUG
                print("📊 ApiService.getStats: Tentando decodificar JSON diretamente como stats")
                #endif
                let statsJson = try JSONSerialization.data(withJSONObject: statsData)
                let decodedStats = try decoder.decode(DashboardStats.self, from: statsJson)
                #if DEBUG
                print("📊 ApiService.getStats: Stats decodificados diretamente - today.revenue=\(decodedStats.today.revenue), week.revenue=\(decodedStats.week.revenue)")
                #endif
                return decodedStats
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
            print("❌ ApiService.getPriorityConversations: Não foi possível criar requisição")
            throw ApiError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ ApiService.getPriorityConversations: Resposta inválida")
                throw ApiError.invalidResponse
            }
            
            #if DEBUG
            print("💬 ApiService.getPriorityConversations: Status \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   Resposta: \(responseString.prefix(500))")
                }
            }
            #endif
            
            // Se não houver dados ou status diferente de 200, retornar array vazio
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    print("❌ ApiService.getPriorityConversations: Não autorizado (401)")
                } else if httpResponse.statusCode == 404 {
                    print("⚠️ ApiService.getPriorityConversations: Endpoint não encontrado (404)")
                }
                // Retornar vazio em vez de erro para não quebrar a UI
                return []
            }
            
            // Tentar parsear como objeto com campo "conversations"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                #if DEBUG
                print("💬 ApiService.getPriorityConversations: JSON parseado, campos: \(json.keys.joined(separator: ", "))")
                #endif
                
                if let conversationsData = json["conversations"] as? [[String: Any]] {
                    #if DEBUG
                    print("💬 ApiService.getPriorityConversations: Encontradas \(conversationsData.count) conversas")
                    #endif
                    
                    let conversationsJson = try JSONSerialization.data(withJSONObject: conversationsData)
                    let conversations = try decoder.decode([PriorityConversation].self, from: conversationsJson)
                    
                    #if DEBUG
                    print("💬 ApiService.getPriorityConversations: \(conversations.count) conversas decodificadas com sucesso")
                    #endif
                    
                    return conversations
                }
                
                // Tentar parsear como array direto
                if let conversationsArray = try? decoder.decode([PriorityConversation].self, from: data) {
                    #if DEBUG
                    print("💬 ApiService.getPriorityConversations: Decodificado como array direto: \(conversationsArray.count) conversas")
                    #endif
                    return conversationsArray
                }
                
                #if DEBUG
                print("⚠️ ApiService.getPriorityConversations: Nenhuma conversa encontrada no JSON")
                #endif
                return []
            }
            
            // Tentar parsear como array direto
            if let conversationsArray = try? decoder.decode([PriorityConversation].self, from: data) {
                #if DEBUG
                print("💬 ApiService.getPriorityConversations: Decodificado como array direto: \(conversationsArray.count) conversas")
                #endif
                return conversationsArray
            }
            
            #if DEBUG
            print("⚠️ ApiService.getPriorityConversations: Não foi possível parsear JSON")
            #endif
            return []
        } catch let urlError as URLError {
            print("❌ ApiService.getPriorityConversations: Erro de rede - \(urlError.localizedDescription)")
            return []
        } catch {
            print("❌ ApiService.getPriorityConversations: Erro desconhecido - \(error.localizedDescription)")
            return []
        }
    }
    
    func sendWhatsAppMessage(phone: String, message: String) async throws -> Bool {
        let url = "\(baseURL)/api/admin/send-whatsapp"
        
        // Criar JSON com camelCase (backend espera camelCase)
        let json: [String: Any] = ["phone": phone, "message": message]
        let body = try JSONSerialization.data(withJSONObject: json)
        
        guard let request = buildRequest(url: url, method: "POST", body: body) else {
            throw ApiError.invalidURL
        }
        
        #if DEBUG
        print("💬 ApiService.sendWhatsAppMessage: Enviando para \(phone)")
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.invalidResponse
        }
        
        #if DEBUG
        print("💬 ApiService.sendWhatsAppMessage: Status \(httpResponse.statusCode)")
        #endif
        
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ ApiService.sendWhatsAppMessage: Erro - \(responseString.prefix(200))")
            }
            throw ApiError.requestFailed
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            return success
        }
        
        return false
    }
    
    func getConversationHistory(phone: String) async throws -> [ChatMessage] {
        let url = "\(baseURL)/api/admin/conversation-history?phone=\(phone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? phone)"
        
        guard let request = buildRequest(url: url, method: "GET") else {
            throw ApiError.invalidURL
        }
        
        #if DEBUG
        print("💬 ApiService.getConversationHistory: Buscando histórico para \(phone)")
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.invalidResponse
        }
        
        #if DEBUG
        print("💬 ApiService.getConversationHistory: Status \(httpResponse.statusCode)")
        #endif
        
        // Se retornar 404, significa que a rota ainda não existe ou não há histórico
        // Tratar como lista vazia ao invés de erro
        if httpResponse.statusCode == 404 {
            #if DEBUG
            print("💬 ApiService.getConversationHistory: Rota não encontrada (404) - retornando lista vazia")
            #endif
            return []
        }
        
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ ApiService.getConversationHistory: Erro \(httpResponse.statusCode) - \(responseString.prefix(200))")
            }
            // Para outros erros, também retornar lista vazia ao invés de quebrar o app
            #if DEBUG
            print("💬 ApiService.getConversationHistory: Retornando lista vazia devido ao erro")
            #endif
            return []
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           success,
           let messagesArray = json["messages"] as? [[String: Any]] {
            
            var messages: [ChatMessage] = []
            let formatter = ISO8601DateFormatter()
            
            for msgDict in messagesArray {
                guard let id = msgDict["id"] as? String,
                      let text = msgDict["text"] as? String,
                      let isAttendant = msgDict["isAttendant"] as? Bool,
                      let timestampStr = msgDict["timestamp"] as? String,
                      let timestamp = formatter.date(from: timestampStr) else {
                    continue
                }
                
                let statusStr = msgDict["status"] as? String ?? "sent"
                let status: ChatMessage.MessageStatus = statusStr == "sending" ? .sending :
                                                         statusStr == "error" ? .error : .sent
                
                messages.append(ChatMessage(
                    id: id,
                    text: text,
                    isAttendant: isAttendant,
                    timestamp: timestamp,
                    status: status
                ))
            }
            
            #if DEBUG
            print("💬 ApiService.getConversationHistory: \(messages.count) mensagens carregadas")
            #endif
            
            return messages
        }
        
        return []
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

enum ApiError: LocalizedError {
    case invalidURL
    case invalidResponse
    case loginFailed
    case requestFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida. Verifique a configuração da API."
        case .invalidResponse:
            return "Resposta inválida do servidor."
        case .loginFailed:
            return "Usuário ou senha incorretos."
        case .requestFailed:
            return "Erro ao conectar com o servidor. Verifique sua conexão."
        }
    }
}
