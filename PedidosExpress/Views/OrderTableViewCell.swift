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
        #if DEBUG
        print("📱 OrderTableViewCell.configure: ID=\(order.id), cliente=\(order.customerName), items=\(order.items.count), total=\(order.totalPrice)")
        #endif
        
        // Cliente
        let customerText = order.customerName.isEmpty ? "Cliente" : order.customerName
        customerLabel.text = customerText.isEmpty ? "Cliente" : customerText
        
        // Itens
        if order.items.isEmpty {
            itemsLabel.text = "Nenhum item"
        } else {
            let itemsText = order.items.map { item in
                let quantity = item.quantity > 0 ? item.quantity : 1
                let name = item.name.isEmpty ? "Item sem nome" : item.name
                return "\(quantity)x \(name)"
            }.joined(separator: ", ")
            itemsLabel.text = itemsText.isEmpty ? "Nenhum item" : itemsText
        }
        
        // Preço
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.currencySymbol = "R$"
        let priceValue = order.totalPrice > 0 ? order.totalPrice : 0.0
        let priceText = formatter.string(from: NSNumber(value: priceValue)) ?? "R$ 0,00"
        priceLabel.text = priceText
        
        // Formatar hora
        if let date = parseDate(order.createdAt) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            timeLabel.text = timeFormatter.string(from: date)
        } else {
            // Tentar outros formatos
            let isoFormatter = ISO8601DateFormatter()
            if let isoDate = isoFormatter.date(from: order.createdAt) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                timeLabel.text = timeFormatter.string(from: isoDate)
            } else {
                timeLabel.text = String(order.createdAt.prefix(5))
            }
        }
        
        // Status
        let statusText: String
        let statusColor: UIColor
        switch order.status {
        case "pending":
            statusText = "Pendente"
            statusColor = .systemOrange
        case "printed":
            statusText = "Impresso"
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
            statusText = order.status.capitalized
            statusColor = .systemGray
        }
        
        statusLabel.text = statusText
        statusLabel.textColor = statusColor
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        // Tentar formato ISO8601 completo primeiro
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Tentar ISO8601 sem frações
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Tentar formato simples
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Tentar formato com Z
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
}
