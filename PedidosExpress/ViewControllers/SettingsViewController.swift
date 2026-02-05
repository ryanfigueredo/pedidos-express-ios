import UIKit

class SettingsViewController: UIViewController {
    private var settingsTableView: UITableView!
    
    private let authService = AuthService()
    private let printerHelper = PrinterHelper()
    private let apiService = ApiService()
    
    private var subscription: Subscription?
    
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
        loadSubscription()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSubscription()
    }
    
    private func loadSubscription() {
        Task {
            do {
                subscription = try await apiService.getSubscription()
                await MainActor.run {
                    settingsTableView.reloadData()
                }
            } catch {
                // Se não houver assinatura ou erro, ocultar a seção
                subscription = nil
                await MainActor.run {
                    settingsTableView.reloadData()
                }
            }
        }
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
            
            // Criar LoginViewController programaticamente
            let loginVC = LoginViewController()
            let navController = UINavigationController(rootViewController: loginVC)
            navController.modalPresentationStyle = .fullScreen
            self?.present(navController, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else {
            return "Não informado"
        }
        
        // Tentar formato ISO8601 com frações de segundos
        var formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "dd/MM/yyyy"
            outputFormatter.locale = Locale(identifier: "pt_BR")
            return outputFormatter.string(from: date)
        }
        
        // Tentar formato ISO8601 sem frações de segundos
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "dd/MM/yyyy"
            outputFormatter.locale = Locale(identifier: "pt_BR")
            return outputFormatter.string(from: date)
        }
        
        // Tentar DateFormatter como fallback
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = dateFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "dd/MM/yyyy"
            outputFormatter.locale = Locale(identifier: "pt_BR")
            return outputFormatter.string(from: date)
        }
        
        // Se nenhum formato funcionar, retornar a string original
        return dateString
    }
    
    private func openPaymentPage() {
        guard let subscription = subscription,
              let url = URL(string: subscription.paymentUrl) else {
            return
        }
        
        UIApplication.shared.open(url)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return subscription != nil ? 2 : 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && subscription != nil {
            return "Assinatura e Plano"
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && subscription != nil {
            // Seção de assinatura: Plano Atual, Último Pagamento, Vencimento, Aviso (se necessário), Botão Pagar
            var rows = 3 // Plano, Pagamento, Vencimento
            if let sub = subscription {
                if sub.isExpired || sub.isExpiringSoon {
                    rows += 1 // Aviso
                }
                rows += 1 // Botão Pagar
            }
            return rows
        }
        return settingsItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell", for: indexPath)
        
        // Resetar propriedades da célula
        cell.textLabel?.text = nil
        cell.textLabel?.numberOfLines = 1
        cell.textLabel?.textColor = .label
        cell.detailTextLabel?.text = nil
        cell.accessoryType = .none
        cell.backgroundColor = .systemBackground
        cell.selectionStyle = .default
        
        if indexPath.section == 0 && subscription != nil {
            // Seção de assinatura
            configureSubscriptionCell(cell, at: indexPath)
        } else {
            // Seção de configurações padrão
            cell.textLabel?.text = settingsItems[indexPath.row]
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    private func configureSubscriptionCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        guard let subscription = subscription else { return }
        
        var rowIndex = indexPath.row
        
        // Plano Atual
        if rowIndex == 0 {
            cell.textLabel?.text = "Plano Atual"
            cell.detailTextLabel?.text = subscription.planName
            cell.accessoryType = .none
            cell.backgroundColor = .systemBackground
            return
        }
        rowIndex -= 1
        
        // Último Pagamento
        if rowIndex == 0 {
            cell.textLabel?.text = "Último Pagamento"
            cell.detailTextLabel?.text = formatDate(subscription.paymentDate)
            cell.accessoryType = .none
            cell.backgroundColor = .systemBackground
            return
        }
        rowIndex -= 1
        
        // Vencimento
        if rowIndex == 0 {
            cell.textLabel?.text = "Vencimento"
            cell.detailTextLabel?.text = formatDate(subscription.expiresAt)
            cell.accessoryType = .none
            cell.backgroundColor = .systemBackground
            return
        }
        rowIndex -= 1
        
        // Aviso (se vencido ou próximo do vencimento)
        if subscription.isExpired || subscription.isExpiringSoon {
            if rowIndex == 0 {
                let message: String
                let backgroundColor: UIColor
                
                if subscription.isExpired {
                    message = "⚠️ Sua assinatura está vencida. Renove agora!"
                    backgroundColor = UIColor(red: 254/255, green: 226/255, blue: 226/255, alpha: 1.0) // #FEE2E2
                } else if let days = subscription.daysUntilExpiration {
                    message = "⚠️ Sua assinatura vence em \(days) dia\(days == 1 ? "" : "s"). Renove agora!"
                    backgroundColor = UIColor(red: 254/255, green: 243/255, blue: 199/255, alpha: 1.0) // #FEF3C7
                } else {
                    message = "⚠️ Sua assinatura está próxima do vencimento. Renove agora!"
                    backgroundColor = UIColor(red: 254/255, green: 243/255, blue: 199/255, alpha: 1.0)
                }
                
                cell.textLabel?.text = message
                cell.textLabel?.numberOfLines = 0
                cell.detailTextLabel?.text = nil
                cell.accessoryType = .none
                cell.backgroundColor = backgroundColor
                cell.selectionStyle = .none
                return
            }
            rowIndex -= 1
        }
        
        // Botão Pagar via PIX
        if rowIndex == 0 {
            cell.textLabel?.text = "Pagar via PIX"
            cell.textLabel?.textColor = .systemBlue
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
            cell.backgroundColor = .systemBackground
            return
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 && subscription != nil {
            // Seção de assinatura
            guard let subscription = subscription else { return }
            
            var rowIndex = indexPath.row
            
            // Pular Plano, Pagamento, Vencimento
            rowIndex -= 3
            
            // Pular Aviso se existir
            if subscription.isExpired || subscription.isExpiringSoon {
                if rowIndex == 0 {
                    // Clicou no aviso, não fazer nada
                    return
                }
                rowIndex -= 1
            }
            
            // Botão Pagar via PIX
            if rowIndex == 0 {
                openPaymentPage()
                return
            }
        } else {
            // Seção de configurações padrão
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
}
