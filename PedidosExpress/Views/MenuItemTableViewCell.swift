import UIKit

class MenuItemTableViewCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let categoryLabel = UILabel()
    private let priceLabel = UILabel()
    private let availableIndicator = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        nameLabel.font = .boldSystemFont(ofSize: 16)
        categoryLabel.font = .systemFont(ofSize: 14)
        categoryLabel.textColor = .secondaryLabel
        priceLabel.font = .boldSystemFont(ofSize: 16)
        priceLabel.textColor = .systemGreen
        
        availableIndicator.layer.cornerRadius = 6
        availableIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [
            nameLabel,
            categoryLabel,
            priceLabel
        ])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        contentView.addSubview(availableIndicator)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: availableIndicator.leadingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            availableIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            availableIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            availableIndicator.widthAnchor.constraint(equalToConstant: 12),
            availableIndicator.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    func configure(with item: MenuItem) {
        nameLabel.text = item.name
        categoryLabel.text = item.category
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        priceLabel.text = formatter.string(from: NSNumber(value: item.price))
        
        availableIndicator.backgroundColor = item.available ? .systemGreen : .systemRed
    }
}
