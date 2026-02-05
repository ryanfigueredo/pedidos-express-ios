import UIKit
import Combine
import os.log

class SettingsViewController: UIViewController {
    private var settingsTableView: UITableView!
    
    private let authService = AuthService()
    private let printerHelper = PrinterHelper()
    private let apiService = ApiService()
    
    private var subscription: Subscription?
    private var cancellables = Set<AnyCancellable>()
    
    private let settingsItems = [
        "Impressora Bluetooth",
        "Sobre",
        "Sair"
    ]
    
    private var user: User?
    private var tenantName: String = "Loja"
    
    private let logger = Logger(subsystem: "com.pedidosexpress", category: "SettingsViewController")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Configurações"
        navigationItem.largeTitleDisplayMode = .never
        user = authService.getUser()
        tenantName = user?.tenantId ?? "Loja"
        setupUI()
        setupTableView()
        loadSubscription()
        observePrinterHelper()
    }
    
    private func observePrinterHelper() {
        // Observar mudanças nas impressoras disponíveis
        printerHelper.$availablePrinters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] printers in
                self?.logger.info("📱 SettingsViewController: \(printers.count) impressoras disponíveis")
            }
            .store(in: &cancellables)
        
        // Observar status de conexão
        printerHelper.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.logger.info("🔌 SettingsViewController: Impressora conectada: \(isConnected)")
            }
            .store(in: &cancellables)
        
        // Observar status de scan
        printerHelper.$isScanning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isScanning in
                if !isScanning {
                    // Scan finalizado, mostrar resultados
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.showPrinterScanResults()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        user = authService.getUser()
        tenantName = user?.tenantId ?? "Loja"
        loadSubscription()
        settingsTableView.reloadData() // Recarregar para atualizar informações
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
        let statusMessage = printerHelper.isConnected ? "Conectada" : "Desconectada"
        let printerCount = printerHelper.availablePrinters.count
        let message = "Status: \(statusMessage)\nImpressoras encontradas: \(printerCount)"
        
        let alert = UIAlertController(title: "Impressora Bluetooth", message: message, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Buscar Impressoras", style: .default) { [weak self] _ in
            let logMsg = "🔍 SettingsViewController: Usuário solicitou busca de impressoras"
            self?.logger.info("\(logMsg)")
            print("\(logMsg)")
            self?.printerHelper.scanForPrinters()
            
            // Mostrar feedback imediato
            let scanningAlert = UIAlertController(
                title: "Buscando Impressoras...",
                message: "Por favor, aguarde. Isso pode levar até 10 segundos.",
                preferredStyle: .alert
            )
            self?.present(scanningAlert, animated: true)
            
            // O alerta será fechado quando o scan terminar (via observePrinterHelper)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.5) {
                scanningAlert.dismiss(animated: true)
            }
        })
        
        // Mostrar lista de impressoras disponíveis
        if !printerHelper.availablePrinters.isEmpty {
            for printer in printerHelper.availablePrinters {
                let printerName = printer.name ?? "Impressora sem nome"
                let isCurrentPrinter = printer.identifier == printerHelper.connectedPeripheral?.identifier
                let actionTitle = isCurrentPrinter ? "\(printerName) ✓" : printerName
                
                alert.addAction(UIAlertAction(title: actionTitle, style: .default) { [weak self] _ in
                    self?.logger.info("🔌 SettingsViewController: Conectando à impressora: \(printerName)")
                    self?.printerHelper.connectToPrinter(printer)
                    
                    let connectingAlert = UIAlertController(
                        title: "Conectando...",
                        message: "Conectando à \(printerName)",
                        preferredStyle: .alert
                    )
                    self?.present(connectingAlert, animated: true)
                    
                    // Aguardar conexão (máximo 10 segundos)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        connectingAlert.dismiss(animated: true)
                        if self?.printerHelper.isConnected == true {
                            self?.showAlert(title: "Conectado", message: "Impressora conectada com sucesso!")
                        } else {
                            self?.showAlert(title: "Erro", message: "Não foi possível conectar à impressora. Verifique se ela está ligada e próxima.")
                        }
                    }
                })
            }
        }
        
        alert.addAction(UIAlertAction(title: "Teste de Impressão", style: .default) { [weak self] _ in
            guard let self = self else { return }
            if self.printerHelper.isConnected {
                self.logger.info("🖨️ SettingsViewController: Teste de impressão solicitado")
                self.printerHelper.testPrint()
                self.showAlert(title: "Enviado", message: "Comando de teste enviado para a impressora.")
            } else {
                self.showAlert(title: "Não Conectado", message: "Conecte uma impressora primeiro.")
            }
        })
        
        if printerHelper.isConnected {
            alert.addAction(UIAlertAction(title: "Desconectar", style: .destructive) { [weak self] _ in
                self?.logger.info("🔌 SettingsViewController: Desconectando impressora")
                self?.printerHelper.disconnect()
                self?.showAlert(title: "Desconectado", message: "Impressora desconectada.")
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        // Para iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func showPrinterScanResults() {
        let count = printerHelper.availablePrinters.count
        if count > 0 {
            let message = "Encontradas \(count) impressora(s).\n\nToque em 'Impressora Bluetooth' novamente para ver a lista e conectar."
            showAlert(title: "Busca Concluída", message: message)
        } else {
            showAlert(
                title: "Nenhuma Impressora Encontrada",
                message: "Não foram encontradas impressoras Bluetooth próximas.\n\nCertifique-se de que:\n• A impressora está ligada\n• O Bluetooth está ativado\n• A impressora está próxima ao dispositivo"
            )
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
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
        var sections = 1 // Sempre tem seção de informações
        if subscription != nil {
            sections += 1 // Seção de assinatura
        }
        sections += 1 // Seção de configurações
        return sections
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Informações"
        } else if section == 1 {
            if subscription != nil {
                return "Assinatura e Plano"
            } else {
                return nil // Seção de configurações (sem título)
            }
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            // Seção de informações: Nome da Loja, Usuário, Conta
            return 3
        } else if section == 1 {
            if subscription != nil {
                // Seção de assinatura: Plano Atual, Último Pagamento, Vencimento, Aviso (se necessário), Botão Pagar
                var rows = 3 // Plano, Pagamento, Vencimento
                if let sub = subscription {
                    if sub.isExpired || sub.isExpiringSoon {
                        rows += 1 // Aviso
                    }
                    rows += 1 // Botão Pagar
                }
                return rows
            } else {
                // Seção de configurações (quando não há subscription)
                return settingsItems.count
            }
        } else {
            // Seção de configurações (quando há subscription)
            return settingsItems.count
        }
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
        
        if indexPath.section == 0 {
            // Seção de informações
            configureInfoCell(cell, at: indexPath)
        } else if indexPath.section == 1 {
            if subscription != nil {
                // Seção de assinatura
                configureSubscriptionCell(cell, at: indexPath)
            } else {
                // Seção de configurações (quando não há subscription)
                cell.textLabel?.text = settingsItems[indexPath.row]
                cell.accessoryType = .disclosureIndicator
            }
        } else {
            // Seção de configurações (quando há subscription)
            cell.textLabel?.text = settingsItems[indexPath.row]
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    private func configureInfoCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        // Garantir que o user está atualizado
        if user == nil {
            user = authService.getUser()
            tenantName = user?.tenantId ?? "Loja"
        }
        
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Nome da Loja"
            let displayName = tenantName.replacingOccurrences(of: "-", with: " ").capitalized
            cell.detailTextLabel?.text = displayName.isEmpty ? "Loja" : displayName
            cell.accessoryType = .none
            cell.selectionStyle = .none
        case 1:
            cell.textLabel?.text = "Usuário"
            cell.detailTextLabel?.text = user?.name ?? "N/A"
            cell.accessoryType = .none
            cell.selectionStyle = .none
        case 2:
            cell.textLabel?.text = "Conta"
            let username = user?.username ?? "N/A"
            cell.detailTextLabel?.text = "@\(username)"
            cell.accessoryType = .none
            cell.selectionStyle = .none
        default:
            break
        }
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
        
        if indexPath.section == 0 {
            // Seção de informações - não é clicável
            return
        } else if indexPath.section == 1 {
            if subscription != nil {
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
                // Seção de configurações (quando não há subscription)
                handleSettingsAction(at: indexPath.row)
            }
        } else {
            // Seção de configurações (quando há subscription)
            handleSettingsAction(at: indexPath.row)
        }
    }
    
    private func handleSettingsAction(at index: Int) {
        switch index {
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
