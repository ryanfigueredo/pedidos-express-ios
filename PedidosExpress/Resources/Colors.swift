import UIKit

extension UIColor {
    // Cores principais do tema laranja
    static let pedidosOrange = UIColor(red: 234/255, green: 88/255, blue: 12/255, alpha: 1.0) // #ea580c
    static let pedidosOrangeDark = UIColor(red: 194/255, green: 65/255, blue: 12/255, alpha: 1.0) // #c2410c
    static let pedidosOrangeLight = UIColor(red: 255/255, green: 247/255, blue: 237/255, alpha: 1.0) // #fff7ed
    
    // Gradientes para cards
    static let gradientOrangeStart = UIColor(red: 234/255, green: 88/255, blue: 12/255, alpha: 1.0) // #ea580c
    static let gradientOrangeEnd = UIColor(red: 249/255, green: 115/255, blue: 22/255, alpha: 1.0) // #f97316
    static let gradientGreenStart = UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1.0) // #22c55e
    static let gradientGreenEnd = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0) // #10b981
    static let gradientPurpleStart = UIColor(red: 168/255, green: 85/255, blue: 247/255, alpha: 1.0) // #a855f7
    static let gradientPurpleEnd = UIColor(red: 139/255, green: 92/255, blue: 246/255, alpha: 1.0) // #8b5cf6
    static let gradientRedStart = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0) // #ef4444
    static let gradientRedEnd = UIColor(red: 220/255, green: 38/255, blue: 38/255, alpha: 1.0) // #dc2626
    
    // Cores de texto
    static let pedidosTextPrimary = UIColor(red: 17/255, green: 24/255, blue: 39/255, alpha: 1.0) // #111827
    static let pedidosTextSecondary = UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1.0) // #6b7280
}

// Helper para criar gradientes
class GradientView: UIView {
    var startColor: UIColor = .gradientOrangeStart
    var endColor: UIColor = .gradientOrangeEnd
    var direction: GradientDirection = .topToBottom
    
    enum GradientDirection {
        case topToBottom
        case leftToRight
        case diagonal
    }
    
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let gradientLayer = layer as? CAGradientLayer else { return }
        
        gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
        
        switch direction {
        case .topToBottom:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        case .leftToRight:
            gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        case .diagonal:
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        }
        
        gradientLayer.cornerRadius = 16
    }
}
