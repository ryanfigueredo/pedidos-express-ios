import UIKit

class SettingsViewController: UIViewController {
    private var settingsTableView: UITableView!
    
    private let authService = AuthService()
    private let printerHelper = PrinterHelper()
    
    private let settingsItems = [
        "Impressora Bluetooth",
        "Sobre",
        "Sair"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Configurações"
        setupUI()
        setupTableView()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        settingsTableView = UITableView(frame: .zero, style: .insetGrouped)
        settingsTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsTableView)
        
        NSLayoutConstraint.activate([
            settingsTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            settingsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupTableView() {
        settingsTableView.delegate = self
        settingsTableView.dataSource = self
        settingsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingCell")
    }
    
    private func showPrinterSettings() {
        let alert = UIAlertController(title: "Impressora Bluetooth", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Buscar Impressoras", style: .default) { [weak self] _ in
            self?.printerHelper.scanForPrinters()
        })
        
        alert.addAction(UIAlertAction(title: "Teste de Impressão", style: .default) { [weak self] _ in
            self?.printerHelper.testPrint()
        })
        
        alert.addAction(UIAlertAction(title: "Desconectar", style: .destructive) { [weak self] _ in
            self?.printerHelper.disconnect()
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showAbout() {
        let alert = UIAlertController(
            title: "Pedidos Express",
            message: "Versão 1.0.1\n\nApp para gerenciamento de pedidos e atendimentos.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func logout() {
        let alert = UIAlertController(title: "Sair", message: "Deseja realmente sair?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Sair", style: .destructive) { [weak self] _ in
            self?.authService.logout()
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                let navController = UINavigationController(rootViewController: loginVC)
                navController.modalPresentationStyle = .fullScreen
                self?.present(navController, animated: true)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell", for: indexPath)
        cell.textLabel?.text = settingsItems[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.row {
        case 0:
            showPrinterSettings()
        case 1:
            showAbout()
        case 2:
            logout()
        default:
            break
        }
    }
}
