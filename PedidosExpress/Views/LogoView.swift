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
            
            // Fundo BRANCO sólido
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Desenhar ícone de recibo em laranja (MENOR - ocupando ~50% do espaço)
            let pedidosOrange = UIColor(red: 234/255, green: 88/255, blue: 12/255, alpha: 1.0)
            cgContext.setFillColor(pedidosOrange.cgColor)
            
            // Recibo menor: 50% da largura e 55% da altura (ao invés de 60% e 70%)
            let receiptWidth = size.width * 0.5
            let receiptHeight = size.height * 0.55
            let receiptX = (size.width - receiptWidth) / 2
            let receiptY = (size.height - receiptHeight) / 2
            
            // Criar forma de recibo com bordas arredondadas e parte inferior "rasgada"
            let cornerRadius: CGFloat = size.width * 0.03
            let receiptPath = CGMutablePath()
            
            // Topo arredondado
            receiptPath.move(to: CGPoint(x: receiptX + cornerRadius, y: receiptY + receiptHeight))
            receiptPath.addLine(to: CGPoint(x: receiptX + receiptWidth - cornerRadius, y: receiptY + receiptHeight))
            receiptPath.addQuadCurve(to: CGPoint(x: receiptX + receiptWidth, y: receiptY + receiptHeight - cornerRadius),
                                    control: CGPoint(x: receiptX + receiptWidth, y: receiptY + receiptHeight))
            
            // Lado direito
            receiptPath.addLine(to: CGPoint(x: receiptX + receiptWidth, y: receiptY + cornerRadius))
            receiptPath.addQuadCurve(to: CGPoint(x: receiptX + receiptWidth - cornerRadius, y: receiptY),
                                    control: CGPoint(x: receiptX + receiptWidth, y: receiptY))
            
            // Lado esquerdo
            receiptPath.addLine(to: CGPoint(x: receiptX + cornerRadius, y: receiptY))
            receiptPath.addQuadCurve(to: CGPoint(x: receiptX, y: receiptY + cornerRadius),
                                    control: CGPoint(x: receiptX, y: receiptY))
            
            // Parte inferior com efeito "rasgado" (ondulado)
            let wavePoints = 6
            let waveAmplitude = size.width * 0.015
            for i in 0...wavePoints {
                let progress = CGFloat(i) / CGFloat(wavePoints)
                let x = receiptX + progress * receiptWidth
                let y = receiptY + receiptHeight + (i % 2 == 0 ? waveAmplitude : -waveAmplitude)
                if i == 0 {
                    receiptPath.move(to: CGPoint(x: x, y: y))
                } else {
                    receiptPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            receiptPath.closeSubpath()
            
            cgContext.addPath(receiptPath)
            cgContext.fillPath()
            
            // Linhas horizontais do recibo em laranja mais escuro
            let darkerOrange = UIColor(red: 200/255, green: 70/255, blue: 8/255, alpha: 1.0)
            cgContext.setStrokeColor(darkerOrange.cgColor)
            cgContext.setLineWidth(size.width * 0.015)
            
            let receiptRect = CGRect(x: receiptX, y: receiptY, width: receiptWidth, height: receiptHeight)
            let lineSpacing = receiptHeight * 0.12
            let lineStartX = receiptRect.minX + receiptRect.width * 0.15
            let lineEndX = receiptRect.maxX - receiptRect.width * 0.15
            
            // Linha de título (mais curta)
            let titleY = receiptRect.minY + receiptRect.height * 0.18
            cgContext.move(to: CGPoint(x: lineStartX, y: titleY))
            cgContext.addLine(to: CGPoint(x: lineStartX + receiptRect.width * 0.25, y: titleY))
            
            // Linhas de conteúdo
            for i in 1..<4 {
                let y = receiptRect.minY + receiptRect.height * 0.25 + CGFloat(i) * lineSpacing
                cgContext.move(to: CGPoint(x: lineStartX, y: y))
                cgContext.addLine(to: CGPoint(x: lineEndX, y: y))
            }
            
            cgContext.strokePath()
        }
    }
}
