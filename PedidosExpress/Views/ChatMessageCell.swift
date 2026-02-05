import UIKit

class ChatMessageCell: UITableViewCell {
    private let messageBubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11)
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11)
        return label
    }()
    
    private var bubbleLeadingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(messageBubbleView)
        messageBubbleView.addSubview(messageLabel)
        messageBubbleView.addSubview(timeLabel)
        messageBubbleView.addSubview(statusLabel)
        
        bubbleLeadingConstraint = messageBubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        bubbleTrailingConstraint = messageBubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            messageBubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            messageBubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            messageBubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            
            messageLabel.topAnchor.constraint(equalTo: messageBubbleView.topAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: messageBubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: messageBubbleView.trailingAnchor, constant: -12),
            
            timeLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: messageLabel.leadingAnchor),
            timeLabel.bottomAnchor.constraint(equalTo: messageBubbleView.bottomAnchor, constant: -8),
            
            statusLabel.leadingAnchor.constraint(equalTo: timeLabel.trailingAnchor, constant: 4),
            statusLabel.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: messageBubbleView.trailingAnchor, constant: -12)
        ])
    }
    
    func configure(with message: ChatMessage) {
        messageLabel.text = message.text
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        timeLabel.text = formatter.string(from: message.timestamp)
        
        // Remover constraints antigas
        NSLayoutConstraint.deactivate([bubbleLeadingConstraint, bubbleTrailingConstraint])
        
        if message.isAttendant {
            // Mensagem do atendente (laranja, à direita)
            messageBubbleView.backgroundColor = .pedidosOrange
            messageLabel.textColor = .white
            timeLabel.textColor = .white.withAlphaComponent(0.8)
            
            // Status apenas para mensagens do atendente
            switch message.status {
            case .sending:
                statusLabel.text = "⏳"
                statusLabel.textColor = .white.withAlphaComponent(0.8)
            case .sent:
                statusLabel.text = "✓"
                statusLabel.textColor = .white.withAlphaComponent(0.8)
            case .error:
                statusLabel.text = "✗"
                statusLabel.textColor = .systemRed
            }
            statusLabel.isHidden = false
            
            // Constraints para alinhar à direita
            bubbleLeadingConstraint = messageBubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60)
            bubbleTrailingConstraint = messageBubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        } else {
            // Mensagem do cliente (branco, à esquerda)
            messageBubbleView.backgroundColor = .systemBackground
            messageLabel.textColor = .pedidosTextPrimary
            timeLabel.textColor = .pedidosTextSecondary
            statusLabel.isHidden = true
            
            // Constraints para alinhar à esquerda
            bubbleLeadingConstraint = messageBubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
            bubbleTrailingConstraint = messageBubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60)
        }
        
        NSLayoutConstraint.activate([bubbleLeadingConstraint, bubbleTrailingConstraint])
    }
}
