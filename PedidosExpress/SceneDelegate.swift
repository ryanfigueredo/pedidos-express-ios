import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else {
            print("⚠️ SceneDelegate: Não foi possível obter UIWindowScene")
            return
        }
        
        print("🚀 SceneDelegate: Configurando cena...")
        
        window = UIWindow(windowScene: windowScene)
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
    }
}
