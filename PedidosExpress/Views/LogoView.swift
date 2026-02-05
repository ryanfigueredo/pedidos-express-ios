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
        if let svgPath = Bundle.main.path(forResource: "icon", ofType: "svg"),
           let svgData = try? Data(contentsOf: URL(fileURLWithPath: svgPath)) {
            // Criar imagem a partir do SVG
            // Nota: iOS não suporta SVG nativamente, então vamos criar uma imagem programaticamente
            createIconImage()
        } else {
            // Se não encontrar SVG, criar ícone programaticamente
            createIconImage()
        }
    }
    
    private func createIconImage() {
        // Criar ícone de recibo/pedido usando Core Graphics (baseado no SVG)
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // Escala para desenhar o recibo completo
            let scale: CGFloat = size.width / 32.0 // SVG é 32x32
            
            // Desenhar recibo principal (baseado no SVG)
            cgContext.setFillColor(UIColor.pedidosOrange.cgColor)
            
            // Corpo principal do recibo
            let receiptPath = CGMutablePath()
            receiptPath.move(to: CGPoint(x: 6.5 * scale, y: 2 * scale))
            receiptPath.addLine(to: CGPoint(x: 10.5 * scale, y: 2 * scale))
            receiptPath.addLine(to: CGPoint(x: 26 * scale, y: 2 * scale))
            receiptPath.addLine(to: CGPoint(x: 26 * scale, y: 13 * scale))
            receiptPath.addLine(to: CGPoint(x: 28 * scale, y: 13 * scale))
            receiptPath.addLine(to: CGPoint(x: 28 * scale, y: 11.5 * scale))
            receiptPath.addLine(to: CGPoint(x: 28 * scale, y: 5.5 * scale))
            receiptPath.addLine(to: CGPoint(x: 23 * scale, y: 5.5 * scale))
            receiptPath.addLine(to: CGPoint(x: 23 * scale, y: 27.1 * scale))
            receiptPath.addLine(to: CGPoint(x: 7 * scale, y: 27.1 * scale))
            receiptPath.addLine(to: CGPoint(x: 7 * scale, y: 5.5 * scale))
            receiptPath.closeSubpath()
            
            cgContext.addPath(receiptPath)
            cgContext.fillPath()
            
            // Linhas horizontais do recibo
            cgContext.setStrokeColor(UIColor.pedidosOrange.cgColor)
            cgContext.setLineWidth(scale * 0.5)
            
            let lineYPositions: [CGFloat] = [9, 12, 16, 20]
            for yPos in lineYPositions {
                let y = yPos * scale
                cgContext.move(to: CGPoint(x: 13 * scale, y: y))
                cgContext.addLine(to: CGPoint(x: 19 * scale, y: y))
            }
            
            // Linhas menores à direita
            let smallLineYPositions: [CGFloat] = [12, 16, 20]
            for yPos in smallLineYPositions {
                let y = yPos * scale
                cgContext.move(to: CGPoint(x: 20 * scale, y: y))
                cgContext.addLine(to: CGPoint(x: 21 * scale, y: y))
            }
            
            cgContext.strokePath()
        }
        
        imageView.image = image
        imageView.tintColor = .pedidosOrange
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
            cgContext.fillRect(receiptRect)
            
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
