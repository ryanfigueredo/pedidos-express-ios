import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
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
        
        return true
    }
}
