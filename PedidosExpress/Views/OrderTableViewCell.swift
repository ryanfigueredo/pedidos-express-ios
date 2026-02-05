import UIKit

class OrderTableViewCell: UITableViewCell {
    private let customerLabel = UILabel()
    private let itemsLabel = UILabel()
    private let priceLabel = UILabel()
    private let timeLabel = UILabel()
    private let statusLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        customerLabel.font = .boldSystemFont(ofSize: 16)
        itemsLabel.font = .systemFont(ofSize: 14)
        itemsLabel.textColor = .secondaryLabel
        itemsLabel.numberOfLines = 0
        priceLabel.font = .boldSystemFont(ofSize: 16)
        priceLabel.textColor = .systemGreen
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .secondaryLabel
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textAlignment = .right
        
        let stackView = UIStackView(arrangedSubviews: [
            customerLabel,
            itemsLabel,
            timeLabel,
            priceLabel,
            statusLabel
        ])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with order: Order) {
        customerLabel.text = order.customerName
        
        let itemsText = order.items.map { "\($0.quantity)x \($0.name)" }.joined(separator: ", ")
        itemsLabel.text = itemsText
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        priceLabel.text = formatter.string(from: NSNumber(value: order.totalPrice))
        
        // Formatar hora
        if let date = parseDate(order.createdAt) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeLabel.text = timeFormatter.string(from: date)
        } else {
            timeLabel.text = String(order.createdAt.prefix(5))
        }
        
        // Status
        let statusText: String
        let statusColor: UIColor
        switch order.status {
        case "pending", "printed":
            statusText = "Pendente"
            statusColor = .systemOrange
        case "out_for_delivery":
            statusText = "Em Rota"
            statusColor = .systemBlue
        case "finished":
            statusText = "Entregue"
            statusColor = .systemGreen
        case "cancelled":
            statusText = "Cancelado"
            statusColor = .systemRed
        default:
            statusText = order.status
            statusColor = .systemGray
        }
        
        statusLabel.text = statusText
        statusLabel.textColor = statusColor
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: dateString)
    }
}
