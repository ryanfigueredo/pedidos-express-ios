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
        
        title = "Pedidos"
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
        segmentedControl = UISegmentedControl(items: ["Pedidos", "Rota", "Entregues"])
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
                let sortedOrders = response.orders.sorted { 
                    // Ordenar por data de criação (mais recente primeiro)
                    let date1 = ISO8601DateFormatter().date(from: $0.createdAt) ?? Date.distantPast
                    let date2 = ISO8601DateFormatter().date(from: $1.createdAt) ?? Date.distantPast
                    return date1 > date2
                }
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.allOrders = sortedOrders
                    self.filterOrders()
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
        
        updateSegmentTitles()
        ordersTableView.reloadData()
    }
    
    private func updateSegmentTitles() {
        let pendingCount = allOrders.filter { $0.status == "pending" || $0.status == "printed" }.count
        let deliveryCount = allOrders.filter { $0.status == "out_for_delivery" }.count
        let finishedCount = allOrders.filter { $0.status == "finished" || $0.status == "cancelled" }.count
        
        segmentedControl.setTitle("Pedidos (\(pendingCount))", forSegmentAt: 0)
        segmentedControl.setTitle("Rota (\(deliveryCount))", forSegmentAt: 1)
        segmentedControl.setTitle("Entregues (\(finishedCount))", forSegmentAt: 2)
    }
    
    private func showOrderMenu(_ order: Order) {
        let alert = UIAlertController(title: "Opções do Pedido", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Imprimir", style: .default) { [weak self] _ in
            self?.printerHelper.printOrder(order)
        })
        
        alert.addAction(UIAlertAction(title: "Atualizar Status", style: .default) { [weak self] _ in
            self?.showUpdateStatusDialog(order)
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showUpdateStatusDialog(_ order: Order) {
        let alert = UIAlertController(title: "Atualizar Status", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Saiu para Entrega", style: .default) { [weak self] _ in
            self?.updateOrderStatus(order, status: "out_for_delivery")
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar Pedido", style: .destructive) { [weak self] _ in
            self?.updateOrderStatus(order, status: "cancelled")
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
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
        printerHelper.printOrder(order)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let order = filteredOrders[indexPath.row]
        
        let printAction = UIContextualAction(style: .normal, title: "Imprimir") { [weak self] _, _, completion in
            self?.printerHelper.printOrder(order)
            completion(true)
        }
        printAction.backgroundColor = .systemBlue
        
        let menuAction = UIContextualAction(style: .normal, title: "Menu") { [weak self] _, _, completion in
            self?.showOrderMenu(order)
            completion(true)
        }
        menuAction.backgroundColor = .systemGray
        
        return UISwipeActionsConfiguration(actions: [printAction, menuAction])
    }
}
