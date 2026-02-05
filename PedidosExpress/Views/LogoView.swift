import UIKit

class LogoView: UIView {
    private var imageView: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Criar container com efeito glassmorphism
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Aplicar efeito de vidro líquido
        containerView.backgroundColor = UIColor.pedidosOrange.withAlphaComponent(0.15)
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        // Sombra suave
        containerView.layer.shadowColor = UIColor.pedidosOrange.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOpacity = 0.3
        
        // Blur effect (glassmorphism)
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 16
        blurView.clipsToBounds = true
        
        // ImageView para o ícone
        imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .pedidosOrange
        
        // Carregar o SVG como imagem
        loadSVGIcon()
        
        containerView.addSubview(blurView)
        containerView.addSubview(imageView)
        addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            blurView.topAnchor.constraint(equalTo: containerView.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            imageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.7),
            imageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.7)
        ])
    }
    
    private func loadSVGIcon() {
        // Tentar carregar o SVG do bundle
        if Bundle.main.path(forResource: "icon", ofType: "svg") != nil {
            // Criar imagem a partir do SVG
            // Nota: iOS não suporta SVG nativamente, então vamos criar uma imagem programaticamente
            createIconImage()
        } else {
            // Se não encontrar SVG, criar ícone programaticamente
            createIconImage()
        }
    }
    
    private func createIconImage() {
        // Criar ícone de entrega (homem em scooter) usando Core Graphics
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // Fundo circular com gradiente laranja
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4
            
            // Gradiente de fundo
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor.pedidosOrange.withAlphaComponent(0.2).cgColor,
                UIColor.pedidosOrange.withAlphaComponent(0.4).cgColor
            ]
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!
            cgContext.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: []
            )
            
            // Desenhar scooter (retângulo arredondado)
            let scooterWidth: CGFloat = size.width * 0.6
            let scooterHeight: CGFloat = size.height * 0.15
            let scooterY = size.height * 0.7
            let scooterX = (size.width - scooterWidth) / 2
            
            cgContext.setFillColor(UIColor.pedidosOrange.cgColor)
            let scooterRect = CGRect(x: scooterX, y: scooterY, width: scooterWidth, height: scooterHeight)
            let scooterPath = UIBezierPath(roundedRect: scooterRect, cornerRadius: scooterHeight / 2)
            cgContext.addPath(scooterPath.cgPath)
            cgContext.fillPath()
            
            // Rodas do scooter
            let wheelRadius: CGFloat = size.width * 0.08
            let wheelY = scooterY + scooterHeight
            
            // Roda esquerda
            cgContext.setFillColor(UIColor.darkGray.cgColor)
            cgContext.fillEllipse(in: CGRect(
                x: scooterX + scooterWidth * 0.2 - wheelRadius,
                y: wheelY - wheelRadius,
                width: wheelRadius * 2,
                height: wheelRadius * 2
            ))
            
            // Roda direita
            cgContext.fillEllipse(in: CGRect(
                x: scooterX + scooterWidth * 0.8 - wheelRadius,
                y: wheelY - wheelRadius,
                width: wheelRadius * 2,
                height: wheelRadius * 2
            ))
            
            // Corpo do entregador (círculo para cabeça, retângulo para corpo)
            let headRadius: CGFloat = size.width * 0.12
            let headY = scooterY - headRadius - size.height * 0.05
            
            // Cabeça
            cgContext.setFillColor(UIColor.pedidosOrange.cgColor)
            cgContext.fillEllipse(in: CGRect(
                x: center.x - headRadius,
                y: headY - headRadius,
                width: headRadius * 2,
                height: headRadius * 2
            ))
            
            // Corpo (retângulo arredondado)
            let bodyWidth: CGFloat = size.width * 0.25
            let bodyHeight: CGFloat = size.height * 0.2
            let bodyRect = CGRect(
                x: center.x - bodyWidth / 2,
                y: headY + headRadius,
                width: bodyWidth,
                height: bodyHeight
            )
            let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: 4)
            cgContext.addPath(bodyPath.cgPath)
            cgContext.fillPath()
            
            // Braços estendidos
            let armWidth: CGFloat = size.width * 0.08
            let armHeight: CGFloat = size.height * 0.12
            let armY = headY + headRadius + bodyHeight * 0.2
            
            // Braço esquerdo
            cgContext.fillEllipse(in: CGRect(
                x: center.x - bodyWidth / 2 - armWidth,
                y: armY,
                width: armWidth,
                height: armHeight
            ))
            
            // Braço direito
            cgContext.fillEllipse(in: CGRect(
                x: center.x + bodyWidth / 2,
                y: armY,
                width: armWidth,
                height: armHeight
            ))
            
            // Bolsa de entrega (pequeno retângulo na parte de trás)
            let bagWidth: CGFloat = size.width * 0.15
            let bagHeight: CGFloat = size.height * 0.12
            let bagRect = CGRect(
                x: center.x + bodyWidth / 2 - bagWidth * 0.3,
                y: headY + headRadius + bodyHeight * 0.3,
                width: bagWidth,
                height: bagHeight
            )
            let bagPath = UIBezierPath(roundedRect: bagRect, cornerRadius: 3)
            cgContext.setFillColor(UIColor.pedidosOrange.withAlphaComponent(0.8).cgColor)
            cgContext.addPath(bagPath.cgPath)
            cgContext.fillPath()
        }
        
        imageView.image = image
        imageView.tintColor = nil // Não aplicar tint, já temos cores definidas
    }
}

// Versão simplificada para usar como ícone do app
extension LogoView {
    static func createAppIcon(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Fundo com gradiente laranja
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor(red: 234/255, green: 88/255, blue: 12/255, alpha: 1.0).cgColor,
                UIColor(red: 249/255, green: 115/255, blue: 22/255, alpha: 1.0).cgColor
            ]
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!
            
            cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Efeito de vidro líquido (overlay branco semi-transparente)
            cgContext.setFillColor(UIColor.white.withAlphaComponent(0.2).cgColor)
            let glassRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.4)
            cgContext.fill(glassRect)
            
            // Desenhar ícone de recibo branco
            cgContext.setFillColor(UIColor.white.cgColor)
            let receiptWidth = size.width * 0.6
            let receiptHeight = size.height * 0.7
            let receiptX = (size.width - receiptWidth) / 2
            let receiptY = (size.height - receiptHeight) / 2
            
            let receiptRect = CGRect(x: receiptX, y: receiptY, width: receiptWidth, height: receiptHeight)
            cgContext.fill(receiptRect)
            
            // Linhas do recibo em laranja
            cgContext.setStrokeColor(UIColor(red: 234/255, green: 88/255, blue: 12/255, alpha: 1.0).cgColor)
            cgContext.setLineWidth(size.width * 0.02)
            
            for i in 0..<5 {
                let y = receiptRect.minY + receiptRect.height * 0.2 + CGFloat(i) * receiptRect.height * 0.15
                cgContext.move(to: CGPoint(x: receiptRect.minX + receiptRect.width * 0.1, y: y))
                cgContext.addLine(to: CGPoint(x: receiptRect.maxX - receiptRect.width * 0.1, y: y))
            }
            cgContext.strokePath()
        }
    }
}
