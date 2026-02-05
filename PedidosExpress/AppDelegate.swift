import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("🚀 AppDelegate: Iniciando aplicação...")
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = .systemBackground
        
        let authService = AuthService()
        let isLoggedIn = authService.isLoggedIn()
        print("🔐 Usuário logado: \(isLoggedIn)")
        
        if isLoggedIn {
            let mainVC = MainNavigationViewController()
            print("✅ MainNavigationViewController criado programaticamente")
            window?.rootViewController = mainVC
        } else {
            let loginVC = LoginViewController()
            print("✅ LoginViewController criado programaticamente")
            window?.rootViewController = UINavigationController(rootViewController: loginVC)
        }
        
        window?.makeKeyAndVisible()
        print("✅ Window configurado e visível")
        
        return true
    }
}
