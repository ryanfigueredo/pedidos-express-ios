import UIKit

class MainNavigationViewController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTabBar()
    }
    
    private func setupTabBar() {
        let ordersVC = OrdersViewController()
        ordersVC.tabBarItem = UITabBarItem(title: "Pedidos", image: UIImage(systemName: "list.bullet"), tag: 0)
        
        let dashboardVC = DashboardViewController()
        dashboardVC.tabBarItem = UITabBarItem(title: "Dashboard", image: UIImage(systemName: "chart.bar"), tag: 1)
        
        let menuVC = MenuViewController()
        menuVC.tabBarItem = UITabBarItem(title: "Cardápio", image: UIImage(systemName: "menucard"), tag: 2)
        
        let supportVC = SupportViewController()
        supportVC.tabBarItem = UITabBarItem(title: "Suporte", image: UIImage(systemName: "message"), tag: 3)
        
        let settingsVC = SettingsViewController()
        settingsVC.tabBarItem = UITabBarItem(title: "Config", image: UIImage(systemName: "gearshape"), tag: 4)
        
        viewControllers = [
            UINavigationController(rootViewController: ordersVC),
            UINavigationController(rootViewController: dashboardVC),
            UINavigationController(rootViewController: menuVC),
            UINavigationController(rootViewController: supportVC),
            UINavigationController(rootViewController: settingsVC)
        ]
        
        selectedIndex = 0
    }
}
