import Foundation

class AuthService {
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private let userKey = "saved_user"
    private let usernameKey = "saved_username"
    private let passwordKey = "saved_password"
    private let isLoggedInKey = "is_logged_in"
    
    func saveUser(_ user: User, username: String, password: String) {
        print("💾 AuthService: Salvando credenciais para usuário: \(username)")
        if let userData = try? encoder.encode(user) {
            userDefaults.set(userData, forKey: userKey)
            print("✅ AuthService: Dados do usuário salvos")
        } else {
            print("⚠️ AuthService: Erro ao codificar dados do usuário")
        }
        userDefaults.set(username, forKey: usernameKey)
        userDefaults.set(password, forKey: passwordKey)
        userDefaults.set(true, forKey: isLoggedInKey)
        
        // Sincronizar imediatamente
        userDefaults.synchronize()
        
        // Verificar se foi salvo corretamente
        if let savedUsername = userDefaults.string(forKey: usernameKey),
           let savedPassword = userDefaults.string(forKey: passwordKey) {
            print("✅ AuthService: Credenciais verificadas após salvar - username: \(savedUsername), password presente: \(!savedPassword.isEmpty)")
        } else {
            print("❌ AuthService: ERRO - Credenciais NÃO foram salvas corretamente!")
        }
    }
    
    func saveUserWithoutPassword(_ user: User, username: String) {
        if let userData = try? encoder.encode(user) {
            userDefaults.set(userData, forKey: userKey)
        }
        userDefaults.set(username, forKey: usernameKey)
        userDefaults.removeObject(forKey: passwordKey) // Remove senha salva
        userDefaults.set(true, forKey: isLoggedInKey)
    }
    
    func getUser() -> User? {
        guard let userData = userDefaults.data(forKey: userKey) else {
            return nil
        }
        return try? decoder.decode(User.self, from: userData)
    }
    
    func getCredentials() -> (username: String, password: String)? {
        guard let username = userDefaults.string(forKey: usernameKey),
              let password = userDefaults.string(forKey: passwordKey) else {
            print("⚠️ AuthService.getCredentials: Credenciais não encontradas (usernameKey existe: \(userDefaults.string(forKey: usernameKey) != nil), passwordKey existe: \(userDefaults.string(forKey: passwordKey) != nil))")
            return nil
        }
        print("✅ AuthService.getCredentials: Credenciais encontradas para usuário: \(username)")
        return (username, password)
    }
    
    func isLoggedIn() -> Bool {
        return userDefaults.bool(forKey: isLoggedInKey) && getUser() != nil
    }
    
    func logout() {
        userDefaults.removeObject(forKey: userKey)
        userDefaults.removeObject(forKey: usernameKey)
        userDefaults.removeObject(forKey: passwordKey)
        userDefaults.set(false, forKey: isLoggedInKey)
    }
}
