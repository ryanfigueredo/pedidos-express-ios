import UIKit

class MainNavigationViewController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("📱 MainNavigationViewController: viewDidLoad chamado")
        print("📱 ViewControllers existentes: \(viewControllers?.count ?? 0)")
        
        // Aplicar tema laranja
        applyOrangeTheme()
        
        // Verificar se os ViewControllers já foram configurados pelo storyboard
        // Se não, configurar programaticamente
        if viewControllers == nil || viewControllers?.isEmpty == true {
            print("📱 Configurando TabBar programaticamente...")
            setupTabBar()
        } else {
            print("📱 TabBar já configurado pelo storyboard")
        }
    }
    
    private func applyOrangeTheme() {
        // TabBar
        tabBar.tintColor = .pedidosOrange
        tabBar.unselectedItemTintColor = .pedidosTextSecondary
        tabBar.backgroundColor = .systemBackground
        
        // Navigation Bar (para cada view controller)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.pedidosOrange]
        // Configurar large title text attributes também (caso seja habilitado em algum lugar)
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.pedidosOrange]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = .pedidosOrange
        // Desabilitar large titles globalmente para evitar duplicação
        UINavigationBar.appearance().prefersLargeTitles = false
    }
    
    private func setupTabBar() {
        let ordersVC = OrdersViewController()
        let authService = AuthService()
        let user = authService.getUser()
        let ordersLabel = BusinessTypeHelper.ordersLabel(for: user)
        ordersVC.tabBarItem = UITabBarItem(title: ordersLabel, image: UIImage(systemName: "list.bullet"), tag: 0)
        
        let dashboardVC = DashboardViewController()
        dashboardVC.tabBarItem = UITabBarItem(title: "Dashboard", image: UIImage(systemName: "chart.bar"), tag: 1)
        
        let menuVC = MenuViewController()
        let menuLabel = BusinessTypeHelper.menuLabel(for: user)
        menuVC.tabBarItem = UITabBarItem(title: menuLabel, image: UIImage(systemName: "menucard"), tag: 2)
        
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
