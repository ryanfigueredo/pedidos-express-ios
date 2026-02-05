import UIKit
import CoreBluetooth

class OrdersViewController: UIViewController {
    private var ordersTableView: UITableView!
    private var progressIndicator: UIActivityIndicatorView!
    private var segmentedControl: UISegmentedControl!
    private var refreshControl: UIRefreshControl!
    
    private let apiService = ApiService()
    private let printerHelper = PrinterHelper()
    
    private var allOrders: [Order] = []
    private var filteredOrders: [Order] = []
    private var currentSection: OrderSection = .pending
    private var printedOrderIds = Set<String>()
    private var refreshTimer: Timer?
    
    enum OrderSection: Int {
        case pending = 0
        case outForDelivery = 1
        case finished = 2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let authService = AuthService()
        let user = authService.getUser()
        title = BusinessTypeHelper.ordersLabel(for: user)
        navigationItem.largeTitleDisplayMode = .never
        setupUI()
        setupTableView()
        requestBluetoothPermissions()
        loadOrders()
        startAutoRefresh()
    }
    
    private func setupUI() {
        view.backgroundColor = .pedidosOrangeLight
        
        // Segmented Control
        let authService = AuthService()
        let user = authService.getUser()
        let pendingLabel = BusinessTypeHelper.pendingOrdersLabel(for: user)
        let outForDeliveryLabel = BusinessTypeHelper.outForDeliveryLabel(for: user)
        let finishedLabel = BusinessTypeHelper.finishedOrdersLabel(for: user)
        segmentedControl = UISegmentedControl(items: [pendingLabel, outForDeliveryLabel, finishedLabel])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        view.addSubview(segmentedControl)
        
        // Table View
        ordersTableView = UITableView()
        ordersTableView.backgroundColor = .pedidosOrangeLight
        ordersTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ordersTableView)
        
        // Progress Indicator
        progressIndicator = UIActivityIndicatorView(style: .large)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.hidesWhenStopped = true
        view.addSubview(progressIndicator)
        
        // Refresh Control
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshOrders), for: .valueChanged)
        ordersTableView.refreshControl = refreshControl
        
        // Navigation Bar Button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Teste",
            style: .plain,
            target: self,
            action: #selector(testPrint)
        )
        
        // Constraints
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            ordersTableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            ordersTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ordersTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ordersTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    private func setupTableView() {
        ordersTableView.delegate = self
        ordersTableView.dataSource = self
        ordersTableView.register(OrderTableViewCell.self, forCellReuseIdentifier: "OrderCell")
    }
    
    private func requestBluetoothPermissions() {
        // No iOS, as permissões Bluetooth são solicitadas automaticamente quando necessário
        // O estado será verificado quando tentarmos usar o Bluetooth
    }
    
    @objc private func segmentChanged() {
        guard let section = OrderSection(rawValue: segmentedControl.selectedSegmentIndex) else { return }
        currentSection = section
        filterOrders()
    }
    
    @objc private func refreshOrders() {
        loadOrders(silent: false)
    }
    
    @objc private func testPrint() {
        printerHelper.testPrint()
    }
    
    private func startAutoRefresh() {
        // Garantir que o timer seja criado no thread principal
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                self.loadOrders(silent: true)
            }
        }
    }
    
    private func loadOrders(silent: Bool = false) {
        // Garantir que estamos no thread principal para atualizar UI
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.loadOrders(silent: silent)
            }
            return
        }
        
        if !silent {
            progressIndicator.startAnimating()
        }
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let response = try await self.apiService.getAllOrders(page: 1, limit: 100)
                
                #if DEBUG
                print("📱 OrdersViewController: Recebidos \(response.orders.count) pedidos da API")
                #endif
                
                let sortedOrders = response.orders.sorted { 
                    // Ordenar por data de criação (mais recente primeiro)
                    let date1 = ISO8601DateFormatter().date(from: $0.createdAt) ?? Date.distantPast
                    let date2 = ISO8601DateFormatter().date(from: $1.createdAt) ?? Date.distantPast
                    return date1 > date2
                }
                
                #if DEBUG
                print("📱 OrdersViewController: Após ordenação: \(sortedOrders.count) pedidos")
                #endif
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.allOrders = sortedOrders
                    self.filterOrders()
                    
                    #if DEBUG
                    print("📱 OrdersViewController: allOrders = \(self.allOrders.count), filteredOrders = \(self.filteredOrders.count)")
                    #endif
                    
                    self.detectAndPrintNewOrders(sortedOrders)
                    
                    if !silent {
                        self.progressIndicator.stopAnimating()
                        self.refreshControl.endRefreshing()
                    }
                    
                    // Se não houver pedidos, não mostrar erro (é normal)
                    if sortedOrders.isEmpty && !silent {
                        // Opcional: mostrar mensagem informativa
                        // self.showAlert(title: "Info", message: "Nenhum pedido encontrado")
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    if !silent {
                        self.progressIndicator.stopAnimating()
                        self.refreshControl.endRefreshing()
                        
                        // Mensagem mais amigável
                        var errorMessage = "Erro ao carregar pedidos."
                        if let urlError = error as? URLError {
                            switch urlError.code {
                            case .notConnectedToInternet, .networkConnectionLost:
                                errorMessage = "Sem conexão com a internet. Verifique sua conexão."
                            case .timedOut:
                                errorMessage = "Tempo de conexão esgotado. Tente novamente."
                            default:
                                errorMessage = "Erro de conexão: \(urlError.localizedDescription)"
                            }
                        } else {
                            errorMessage = "Erro: \(error.localizedDescription)"
                        }
                        
                        self.showAlert(title: "Erro", message: errorMessage)
                    }
                }
            }
        }
    }
    
    private func detectAndPrintNewOrders(_ orders: [Order]) {
        for order in orders {
            if order.status == "pending" &&
               !printedOrderIds.contains(order.id) &&
               order.printRequestedAt != nil {
                
                printedOrderIds.insert(order.id)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.printerHelper.printOrder(order)
                    
                    Task {
                        do {
                            try await self?.apiService.updateOrderStatus(orderId: order.id, status: "printed")
                        } catch {
                            print("Erro ao marcar como impresso: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func filterOrders() {
        switch currentSection {
        case .pending:
            filteredOrders = allOrders.filter { $0.status == "pending" || $0.status == "printed" }
        case .outForDelivery:
            filteredOrders = allOrders.filter { $0.status == "out_for_delivery" }
        case .finished:
            filteredOrders = allOrders.filter { $0.status == "finished" || $0.status == "cancelled" }
        }
        
        #if DEBUG
        print("📱 filterOrders: Seção atual = \(currentSection), allOrders = \(allOrders.count), filteredOrders = \(filteredOrders.count)")
        for (index, order) in filteredOrders.prefix(3).enumerated() {
            print("   Pedido \(index + 1): ID=\(order.id), status=\(order.status), cliente=\(order.customerName)")
        }
        #endif
        
        updateSegmentTitles()
        ordersTableView.reloadData()
    }
    
    private func updateSegmentTitles() {
        let pendingCount = allOrders.filter { $0.status == "pending" || $0.status == "printed" }.count
        let deliveryCount = allOrders.filter { $0.status == "out_for_delivery" }.count
        let finishedCount = allOrders.filter { $0.status == "finished" || $0.status == "cancelled" }.count
        
        let authService = AuthService()
        let user = authService.getUser()
        let pendingLabel = BusinessTypeHelper.pendingOrdersLabel(for: user)
        let outForDeliveryLabel = BusinessTypeHelper.outForDeliveryLabel(for: user)
        let finishedLabel = BusinessTypeHelper.finishedOrdersLabel(for: user)
        
        segmentedControl.setTitle("\(pendingLabel) (\(pendingCount))", forSegmentAt: 0)
        segmentedControl.setTitle("\(outForDeliveryLabel) (\(deliveryCount))", forSegmentAt: 1)
        segmentedControl.setTitle("\(finishedLabel) (\(finishedCount))", forSegmentAt: 2)
    }
    
    private func showOrderMenu(_ order: Order) {
        let authService = AuthService()
        let user = authService.getUser()
        let orderLabel = BusinessTypeHelper.orderLabel(for: user)
        let alert = UIAlertController(title: "Opções do \(orderLabel)", message: nil, preferredStyle: .actionSheet)
        
        // Se estiver em rota, mostrar opções de entrega
        if order.status == "out_for_delivery" {
            alert.addAction(UIAlertAction(title: "Confirmar Entrega", style: .default) { [weak self] _ in
                self?.confirmDelivery(order)
            })
            
            alert.addAction(UIAlertAction(title: "Reportar Problema", style: .destructive) { [weak self] _ in
                self?.reportDeliveryProblem(order)
            })
        } else {
            // Opções normais para pedidos pendentes/impressos
            alert.addAction(UIAlertAction(title: "Imprimir", style: .default) { [weak self] _ in
                self?.printerHelper.printOrder(order)
            })
            
            alert.addAction(UIAlertAction(title: "Editar", style: .default) { [weak self] _ in
                self?.showEditOrderDialog(order)
            })
            
            alert.addAction(UIAlertAction(title: "Enviar para Entrega", style: .default) { [weak self] _ in
                self?.updateOrderStatus(order, status: "out_for_delivery")
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        // Para iPad, precisa configurar o popover
        if let popover = alert.popoverPresentationController {
            if let cell = ordersTableView.cellForRow(at: IndexPath(row: filteredOrders.firstIndex(where: { $0.id == order.id }) ?? 0, section: 0)) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }
        
        present(alert, animated: true)
    }
    
    private func confirmDelivery(_ order: Order) {
        let alert = UIAlertController(
            title: "Confirmar Entrega",
            message: "Deseja confirmar a entrega deste pedido?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Confirmar", style: .default) { [weak self] _ in
            self?.updateOrderStatus(order, status: "finished")
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func reportDeliveryProblem(_ order: Order) {
        let alert = UIAlertController(
            title: "Reportar Problema",
            message: "Descreva o problema encontrado na entrega:",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Ex: Cliente não estava em casa"
        }
        
        alert.addAction(UIAlertAction(title: "Reportar", style: .destructive) { [weak self] _ in
            let _ = alert.textFields?.first?.text ?? "Problema na entrega"
            // Por enquanto, apenas atualizar status para pending novamente
            // TODO: Implementar endpoint para reportar problemas
            self?.updateOrderStatus(order, status: "pending")
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showEditOrderDialog(_ order: Order) {
        // Por enquanto, mostrar um alerta informativo
        // TODO: Implementar tela de edição completa
        let alert = UIAlertController(
            title: "Editar Pedido",
            message: "Funcionalidade de edição será implementada em breve.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
    
    private func updateOrderStatus(_ order: Order, status: String) {
        progressIndicator.startAnimating()
        
        Task {
            do {
                try await apiService.updateOrderStatus(orderId: order.id, status: status)
                
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    self.loadOrders()
                }
            } catch {
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    self.showAlert(title: "Erro", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension OrdersViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredOrders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OrderCell", for: indexPath) as! OrderTableViewCell
        let order = filteredOrders[indexPath.row]
        cell.configure(with: order)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let order = filteredOrders[indexPath.row]
        showOrderMenu(order)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let order = filteredOrders[indexPath.row]
        
        // Se estiver em rota, mostrar ações rápidas de entrega
        if order.status == "out_for_delivery" {
            let confirmAction = UIContextualAction(style: .normal, title: "Entregue") { [weak self] _, _, completion in
                self?.confirmDelivery(order)
                completion(true)
            }
            confirmAction.backgroundColor = .systemGreen
            
            let problemAction = UIContextualAction(style: .destructive, title: "Problema") { [weak self] _, _, completion in
                self?.reportDeliveryProblem(order)
                completion(true)
            }
            
            return UISwipeActionsConfiguration(actions: [confirmAction, problemAction])
        } else {
            // Para outros status, mostrar ação rápida de imprimir
            let printAction = UIContextualAction(style: .normal, title: "Imprimir") { [weak self] _, _, completion in
                self?.printerHelper.printOrder(order)
                completion(true)
            }
            printAction.backgroundColor = .systemBlue
            
            return UISwipeActionsConfiguration(actions: [printAction])
        }
    }
}
