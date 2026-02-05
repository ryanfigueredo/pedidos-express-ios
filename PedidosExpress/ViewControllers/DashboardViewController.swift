import UIKit

class DashboardViewController: UIViewController {
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    
    // Labels para KPIs
    private var todayOrdersLabel: UILabel!
    private var todayRevenueLabel: UILabel!
    private var avgTicketLabel: UILabel!
    private var pendingOrdersLabel: UILabel!
    private var weekOrdersLabel: UILabel!
    private var weekRevenueLabel: UILabel!
    
    private var progressIndicator: UIActivityIndicatorView!
    
    private let apiService = ApiService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dashboard"
        navigationItem.largeTitleDisplayMode = .never
        setupUI()
        loadStats()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadStats()
    }
    
    private func setupUI() {
        view.backgroundColor = .pedidosOrangeLight
        
        // Scroll View
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(contentView)
        view.addSubview(scrollView)
        
        // Stack para cards de KPIs
        let kpiStack = UIStackView()
        kpiStack.axis = .vertical
        kpiStack.spacing = 16
        kpiStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Primeira linha: Pedidos Hoje e Receita Hoje
        let row1 = createKPIStack()
        let card1 = createKPICard(
            icon: "cart.fill",
            value: "0",
            title: BusinessTypeHelper.ordersTodayLabel(for: AuthService().getUser()),
            gradientStart: .gradientOrangeStart,
            gradientEnd: .gradientOrangeEnd
        )
        todayOrdersLabel = card1.valueLabel
        
        let card2 = createKPICard(
            icon: "dollarsign.circle.fill",
            value: "R$ 0,00",
            title: "Receita Hoje",
            gradientStart: .gradientGreenStart,
            gradientEnd: .gradientGreenEnd
        )
        todayRevenueLabel = card2.valueLabel
        
        row1.addArrangedSubview(card1.container)
        row1.addArrangedSubview(card2.container)
        
        // Segunda linha: Ticket Médio e Pendentes
        let row2 = createKPIStack()
        let card3 = createKPICard(
            icon: "receipt.fill",
            value: "R$ 0,00",
            title: "Ticket Médio",
            gradientStart: .gradientPurpleStart,
            gradientEnd: .gradientPurpleEnd
        )
        avgTicketLabel = card3.valueLabel
        
        let card4 = createKPICard(
            icon: "clock.fill",
            value: "0",
            title: "Pendentes",
            gradientStart: .gradientRedStart,
            gradientEnd: .gradientRedEnd
        )
        pendingOrdersLabel = card4.valueLabel
        
        row2.addArrangedSubview(card3.container)
        row2.addArrangedSubview(card4.container)
        
        kpiStack.addArrangedSubview(row1)
        kpiStack.addArrangedSubview(row2)
        
        // Card da Semana
        let weekCard = createWeekCard()
        
        contentView.addSubview(kpiStack)
        contentView.addSubview(weekCard)
        
        progressIndicator = UIActivityIndicatorView(style: .large)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.hidesWhenStopped = true
        view.addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            kpiStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            kpiStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            kpiStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            weekCard.topAnchor.constraint(equalTo: kpiStack.bottomAnchor, constant: 16),
            weekCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            weekCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            weekCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func createKPIStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        return stack
    }
    
    private func createKPICard(icon: String, value: String, title: String, gradientStart: UIColor, gradientEnd: UIColor) -> (container: UIView, valueLabel: UILabel) {
        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 16
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOffset = CGSize(width: 0, height: 4)
        container.layer.shadowRadius = 8
        container.layer.shadowOpacity = 0.1
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let gradientView = GradientView()
        gradientView.startColor = gradientStart
        gradientView.endColor = gradientEnd
        gradientView.direction = .diagonal
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 28, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .white.withAlphaComponent(0.9)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let contentStack = UIStackView(arrangedSubviews: [iconImageView, valueLabel, titleLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(gradientView)
        gradientView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: container.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            
            contentStack.topAnchor.constraint(equalTo: gradientView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: gradientView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: gradientView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: gradientView.bottomAnchor, constant: -16)
        ])
        
        return (container, valueLabel)
    }
    
    private func createWeekCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 8
        card.layer.shadowOpacity = 0.1
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Esta Semana"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .pedidosOrange
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        weekOrdersLabel = UILabel()
        weekOrdersLabel.text = "0"
        weekOrdersLabel.font = .systemFont(ofSize: 18, weight: .bold)
        weekOrdersLabel.textColor = .pedidosTextPrimary
        
        weekRevenueLabel = UILabel()
        weekRevenueLabel.text = "R$ 0,00"
        weekRevenueLabel.font = .systemFont(ofSize: 18, weight: .bold)
        weekRevenueLabel.textColor = .pedidosTextPrimary
        
        let user = AuthService().getUser()
        let ordersLabel = BusinessTypeHelper.ordersLabel(for: user)
        let ordersRow = createInfoRow(label: "\(ordersLabel):", valueLabel: weekOrdersLabel)
        let revenueRow = createInfoRow(label: "Receita:", valueLabel: weekRevenueLabel)
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, ordersRow, revenueRow])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        
        return card
    }
    
    private func createInfoRow(label: String, valueLabel: UILabel) -> UIView {
        let container = UIView()
        
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 16)
        labelView.textColor = .pedidosTextSecondary
        
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        labelView.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(labelView)
        container.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return container
    }
    
    private func loadStats() {
        progressIndicator.startAnimating()
        
        Task {
            do {
                let stats = try await apiService.getStats()
                
                #if DEBUG
                print("📊 Dashboard.loadStats: Recebidos stats - today.orders=\(stats.today.orders), today.revenue=\(stats.today.revenue)")
                #endif
                
                await MainActor.run {
                    self.updateUI(with: stats)
                    self.progressIndicator.stopAnimating()
                }
            } catch {
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    
                    // Mensagem mais amigável
                    var errorMessage = "Erro ao carregar estatísticas."
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
                    
                    // Não mostrar alerta se for erro de rede silencioso
                    // Apenas manter valores padrão (0)
                    print("⚠️ Dashboard: \(errorMessage)")
                }
            }
        }
    }
    
    private func updateUI(with stats: DashboardStats) {
        #if DEBUG
        print("📊 Dashboard.updateUI: today.orders=\(stats.today.orders), today.revenue=\(stats.today.revenue)")
        print("   week.orders=\(stats.week.orders), week.revenue=\(stats.week.revenue), pending=\(stats.pendingOrders)")
        #endif
        
        todayOrdersLabel.text = "\(stats.today.orders)"
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.currencySymbol = "R$"
        
        let todayRevenueText = formatter.string(from: NSNumber(value: stats.today.revenue)) ?? "R$ 0,00"
        todayRevenueLabel.text = todayRevenueText
        
        weekOrdersLabel.text = "\(stats.week.orders)"
        let weekRevenueText = formatter.string(from: NSNumber(value: stats.week.revenue)) ?? "R$ 0,00"
        weekRevenueLabel.text = weekRevenueText
        
        pendingOrdersLabel.text = "\(stats.pendingOrders)"
        
        // Calcular ticket médio
        let avgTicket = stats.today.orders > 0 ? stats.today.revenue / Double(stats.today.orders) : 0.0
        let avgTicketText = formatter.string(from: NSNumber(value: avgTicket)) ?? "R$ 0,00"
        avgTicketLabel.text = avgTicketText
        
        #if DEBUG
        print("   📊 Labels atualizados: hoje=\(todayRevenueText), semana=\(weekRevenueText), ticket=\(avgTicketText)")
        #endif
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
