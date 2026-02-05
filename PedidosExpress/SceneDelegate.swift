import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let authService = AuthService()
        
        if authService.isLoggedIn() {
            if let mainVC = storyboard.instantiateViewController(withIdentifier: "MainNavigationViewController") as? MainNavigationViewController {
                window?.rootViewController = UINavigationController(rootViewController: mainVC)
            }
        } else {
            if let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                window?.rootViewController = UINavigationController(rootViewController: loginVC)
            }
        }
        
        window?.makeKeyAndVisible()
    }
}
