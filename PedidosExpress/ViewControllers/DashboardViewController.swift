import UIKit

class DashboardViewController: UIViewController {
    private var todayOrdersLabel: UILabel!
    private var todayRevenueLabel: UILabel!
    private var weekOrdersLabel: UILabel!
    private var weekRevenueLabel: UILabel!
    private var pendingOrdersLabel: UILabel!
    private var progressIndicator: UIActivityIndicatorView!
    
    private let apiService = ApiService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dashboard"
        setupUI()
        loadStats()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadStats()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        todayOrdersLabel = UILabel()
        todayOrdersLabel.text = "0"
        todayOrdersLabel.font = .systemFont(ofSize: 24, weight: .bold)
        
        todayRevenueLabel = UILabel()
        todayRevenueLabel.text = "R$ 0,00"
        todayRevenueLabel.font = .systemFont(ofSize: 20)
        
        weekOrdersLabel = UILabel()
        weekOrdersLabel.text = "0"
        weekOrdersLabel.font = .systemFont(ofSize: 24, weight: .bold)
        
        weekRevenueLabel = UILabel()
        weekRevenueLabel.text = "R$ 0,00"
        weekRevenueLabel.font = .systemFont(ofSize: 20)
        
        pendingOrdersLabel = UILabel()
        pendingOrdersLabel.text = "0"
        pendingOrdersLabel.font = .systemFont(ofSize: 24, weight: .bold)
        
        progressIndicator = UIActivityIndicatorView(style: .large)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.hidesWhenStopped = true
        
        stackView.addArrangedSubview(createLabelSection(title: "Hoje - Pedidos", label: todayOrdersLabel))
        stackView.addArrangedSubview(createLabelSection(title: "Hoje - Receita", label: todayRevenueLabel))
        stackView.addArrangedSubview(createLabelSection(title: "Semana - Pedidos", label: weekOrdersLabel))
        stackView.addArrangedSubview(createLabelSection(title: "Semana - Receita", label: weekRevenueLabel))
        stackView.addArrangedSubview(createLabelSection(title: "Pendentes", label: pendingOrdersLabel))
        
        view.addSubview(stackView)
        view.addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func createLabelSection(title: String, label: UILabel) -> UIView {
        let container = UIView()
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = .secondaryLabel
        
        label.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            label.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func loadStats() {
        progressIndicator.startAnimating()
        
        Task {
            do {
                let stats = try await apiService.getStats()
                
                await MainActor.run {
                    self.updateUI(with: stats)
                    self.progressIndicator.stopAnimating()
                }
            } catch {
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    self.showAlert(title: "Erro", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func updateUI(with stats: DashboardStats) {
        todayOrdersLabel.text = "\(stats.today.orders)"
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        todayRevenueLabel.text = formatter.string(from: NSNumber(value: stats.today.revenue))
        
        weekOrdersLabel.text = "\(stats.week.orders)"
        weekRevenueLabel.text = formatter.string(from: NSNumber(value: stats.week.revenue))
        
        pendingOrdersLabel.text = "\(stats.pendingOrders)"
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
