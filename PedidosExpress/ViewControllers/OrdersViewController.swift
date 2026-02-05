import UIKit
import CoreBluetooth
import os.log

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
    
    private let logger = Logger(subsystem: "com.pedidosexpress", category: "OrdersViewController")
    
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
                    guard let self = self else { return }
                    self.logger.info("🖨️ OrdersViewController: Auto-imprimindo pedido #\(order.displayId ?? order.id)")
                    
                    if self.printerHelper.isConnected {
                        self.printerHelper.printOrder(order) { success, errorMessage in
                            if !success {
                                self.logger.error("❌ OrdersViewController: Erro ao auto-imprimir: \(errorMessage ?? "Desconhecido")")
                            }
                        }
                    } else {
                        self.logger.warning("⚠️ OrdersViewController: Impressora não conectada, pulando auto-impressão")
                    }
                    
                    Task {
                        do {
                            try await self.apiService.updateOrderStatus(orderId: order.id, status: "printed")
                        } catch {
                            self.logger.error("❌ OrdersViewController: Erro ao marcar como impresso: \(error.localizedDescription)")
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
                self?.printOrder(order)
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
    
    private func printOrder(_ order: Order) {
        let logMsg = "🖨️ OrdersViewController: Tentando imprimir pedido #\(order.displayId ?? order.id)"
        logger.info("\(logMsg)")
        print("\(logMsg)")
        
        guard printerHelper.isConnected else {
            let errorMsg = "❌ OrdersViewController: Impressora não conectada"
            logger.error("\(errorMsg)")
            print("\(errorMsg)")
            showAlert(
                title: "Impressora Não Conectada",
                message: "Conecte uma impressora Bluetooth nas Configurações antes de imprimir."
            )
            return
        }
        
        logger.info("✅ OrdersViewController: Impressora conectada, enviando pedido para impressão...")
        progressIndicator.startAnimating()
        
        printerHelper.printOrder(order) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                self?.progressIndicator.stopAnimating()
                
                if success {
                    self?.logger.info("✅ OrdersViewController: Pedido impresso com sucesso")
                    self?.showAlert(title: "Enviado", message: "Pedido enviado para impressão.")
                } else {
                    self?.logger.error("❌ OrdersViewController: Erro ao imprimir: \(errorMessage ?? "Desconhecido")")
                    self?.showAlert(
                        title: "Erro ao Imprimir",
                        message: errorMessage ?? "Não foi possível imprimir o pedido."
                    )
                }
            }
        }
    }
    
    private func showEditOrderDialog(_ order: Order) {
        logger.info("✏️ OrdersViewController: Editando pedido #\(order.displayId ?? order.id)")
        
        let alert = UIAlertController(
            title: "Editar Pedido #\(order.displayId ?? String(order.id.prefix(8)))",
            message: "Selecione o item para editar:",
            preferredStyle: .actionSheet
        )
        
        // Listar itens do pedido
        for (index, item) in order.items.enumerated() {
            alert.addAction(UIAlertAction(
                title: "\(item.quantity)x \(item.name) - R$ \(String(format: "%.2f", item.price))",
                style: .default
            ) { [weak self] _ in
                self?.showEditItemDialog(order: order, itemIndex: index, item: item)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        // Para iPad
        if let popover = alert.popoverPresentationController {
            if let cell = ordersTableView.cellForRow(at: IndexPath(row: filteredOrders.firstIndex(where: { $0.id == order.id }) ?? 0, section: 0)) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }
        
        present(alert, animated: true)
    }
    
    private func showEditItemDialog(order: Order, itemIndex: Int, item: OrderItem) {
        let alert = UIAlertController(
            title: "Editar Item",
            message: "\(item.name)",
            preferredStyle: .alert
        )
        
        // Campo de quantidade
        alert.addTextField { textField in
            textField.placeholder = "Quantidade"
            textField.keyboardType = .numberPad
            textField.text = "\(item.quantity)"
        }
        
        alert.addAction(UIAlertAction(title: "Salvar", style: .default) { [weak self] _ in
            guard let self = self,
                  let quantityText = alert.textFields?.first?.text,
                  let quantity = Int(quantityText),
                  quantity > 0 else {
                self?.showAlert(title: "Erro", message: "Quantidade inválida.")
                return
            }
            
            self.updateOrderItem(order: order, itemIndex: itemIndex, newQuantity: quantity)
        })
        
        alert.addAction(UIAlertAction(title: "Remover Item", style: .destructive) { [weak self] _ in
            self?.removeOrderItem(order: order, itemIndex: itemIndex)
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func updateOrderItem(order: Order, itemIndex: Int, newQuantity: Int) {
        logger.info("✏️ OrdersViewController: Atualizando item \(itemIndex) do pedido \(order.id) para quantidade \(newQuantity)")
        
        var updatedItems = order.items
        guard itemIndex < updatedItems.count else {
            logger.error("❌ OrdersViewController: Índice de item inválido")
            showAlert(title: "Erro", message: "Item não encontrado.")
            return
        }
        
        // Criar nova instância do item com quantidade atualizada (quantity é let)
        let oldItem = updatedItems[itemIndex]
        updatedItems[itemIndex] = OrderItem(
            id: oldItem.id,
            name: oldItem.name,
            quantity: newQuantity,
            price: oldItem.price
        )
        
        progressIndicator.startAnimating()
        
        Task {
            do {
                try await apiService.updateOrder(orderId: order.id, items: updatedItems)
                logger.info("✅ OrdersViewController: Pedido atualizado com sucesso")
                
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    self.showAlert(title: "Sucesso", message: "Pedido atualizado com sucesso.")
                    self.loadOrders()
                }
            } catch {
                logger.error("❌ OrdersViewController: Erro ao atualizar pedido: \(error.localizedDescription)")
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    self.showAlert(title: "Erro", message: "Não foi possível atualizar o pedido: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func removeOrderItem(order: Order, itemIndex: Int) {
        logger.info("🗑️ OrdersViewController: Removendo item \(itemIndex) do pedido \(order.id)")
        
        var updatedItems = order.items
        guard itemIndex < updatedItems.count else {
            logger.error("❌ OrdersViewController: Índice de item inválido")
            showAlert(title: "Erro", message: "Item não encontrado.")
            return
        }
        
        updatedItems.remove(at: itemIndex)
        
        // Se não sobrou nenhum item, não permitir remover
        guard !updatedItems.isEmpty else {
            showAlert(title: "Erro", message: "Não é possível remover todos os itens do pedido.")
            return
        }
        
        progressIndicator.startAnimating()
        
        Task {
            do {
                try await apiService.updateOrder(orderId: order.id, items: updatedItems)
                logger.info("✅ OrdersViewController: Item removido com sucesso")
                
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    self.showAlert(title: "Sucesso", message: "Item removido com sucesso.")
                    self.loadOrders()
                }
            } catch {
                logger.error("❌ OrdersViewController: Erro ao remover item: \(error.localizedDescription)")
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    self.showAlert(title: "Erro", message: "Não foi possível remover o item: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateOrderStatus(_ order: Order, status: String) {
        let logMsg = "📝 OrdersViewController: Atualizando status do pedido \(order.id) para \(status)"
        logger.info("\(logMsg)")
        print("\(logMsg)")
        progressIndicator.startAnimating()
        
        Task {
            do {
                try await apiService.updateOrderStatus(orderId: order.id, status: status)
                logger.info("✅ OrdersViewController: Status atualizado com sucesso")
                
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    self.loadOrders()
                }
            } catch {
                logger.error("❌ OrdersViewController: Erro ao atualizar status: \(error.localizedDescription)")
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    let errorMsg = error.localizedDescription.isEmpty ? "Não foi possível atualizar o status do pedido." : error.localizedDescription
                    self.showAlert(title: "Erro", message: errorMsg)
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
                guard let self = self else {
                    completion(true)
                    return
                }
                self.logger.info("🖨️ OrdersViewController: Impressão via swipe action para pedido #\(order.displayId ?? order.id)")
                
                if self.printerHelper.isConnected {
                    self.printerHelper.printOrder(order) { success, errorMessage in
                        if !success {
                            DispatchQueue.main.async {
                                self.showAlert(title: "Erro", message: errorMessage ?? "Não foi possível imprimir.")
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showAlert(title: "Impressora Não Conectada", message: "Conecte uma impressora Bluetooth nas Configurações.")
                    }
                }
                completion(true)
            }
            printAction.backgroundColor = .systemBlue
            
            return UISwipeActionsConfiguration(actions: [printAction])
        }
    }
}
