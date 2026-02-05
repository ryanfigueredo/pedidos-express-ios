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
        if let userData = try? encoder.encode(user) {
            userDefaults.set(userData, forKey: userKey)
        }
        userDefaults.set(username, forKey: usernameKey)
        userDefaults.set(password, forKey: passwordKey)
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
            return nil
        }
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
