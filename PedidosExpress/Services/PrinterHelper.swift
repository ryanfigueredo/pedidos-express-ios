import Foundation
import CoreBluetooth
import os.log

class PrinterHelper: NSObject, ObservableObject {
    private var centralManager: CBCentralManager?
    var connectedPeripheral: CBPeripheral?
    private var printerCharacteristic: CBCharacteristic?
    private var pendingPrintCompletion: ((Bool, String?) -> Void)?
    
    @Published var isConnected = false
    @Published var availablePrinters: [CBPeripheral] = []
    @Published var isScanning = false
    
    // UUID padrão SPP (Serial Port Profile) usado pela maioria das impressoras Bluetooth
    // Este é o mesmo UUID usado pelo Android: 00001101-0000-1000-8000-00805f9b34fb
    private let printerServiceUUID = CBUUID(string: "00001101-0000-1000-8000-00805f9b34fb")
    // UUID alternativo usado por algumas impressoras
    private let printerServiceUUIDAlt = CBUUID(string: "0000ff00-0000-1000-8000-00805f9b34fb")
    private let printerCharacteristicUUID = CBUUID(string: "0000ff02-0000-1000-8000-00805f9b34fb")
    // UUIDs padrão de características SPP (usados como fallback)
    private let sppCharacteristicUUID1 = CBUUID(string: "0000fff1-0000-1000-8000-00805f9b34fb")
    private let sppCharacteristicUUID2 = CBUUID(string: "0000fff2-0000-1000-8000-00805f9b34fb")
    
    private let logger = Logger(subsystem: "com.pedidosexpress", category: "PrinterHelper")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func scanForPrinters() {
        let logMessage = "🔍 PrinterHelper: Iniciando busca de impressoras..."
        logger.info("\(logMessage)")
        print("\(logMessage)") // Fallback para sempre aparecer no console
        
        guard let centralManager = centralManager else {
            let errorMsg = "❌ PrinterHelper: centralManager é nil"
            logger.error("\(errorMsg)")
            print("\(errorMsg)") // Fallback
            return
        }
        
        switch centralManager.state {
        case .poweredOn:
            let msg = "✅ PrinterHelper: Bluetooth está ligado"
            logger.info("\(msg)")
            print("\(msg)")
        case .poweredOff:
            let msg = "❌ PrinterHelper: Bluetooth está desligado"
            logger.error("\(msg)")
            print("\(msg)")
            return
        case .unauthorized:
            let msg = "❌ PrinterHelper: Bluetooth não autorizado"
            logger.error("\(msg)")
            print("\(msg)")
            return
        case .unsupported:
            let msg = "❌ PrinterHelper: Bluetooth não suportado"
            logger.error("\(msg)")
            print("\(msg)")
            return
        case .resetting:
            let msg = "⚠️ PrinterHelper: Bluetooth está resetando"
            logger.warning("\(msg)")
            print("\(msg)")
            return
        default:
            let msg = "⚠️ PrinterHelper: Estado do Bluetooth desconhecido: \(centralManager.state.rawValue)"
            logger.warning("\(msg)")
            print("\(msg)")
            return
        }
        
        // Limpar lista anterior
        availablePrinters.removeAll()
        isScanning = true
        
        // Buscar impressoras pareadas (já conectadas)
        // Nota: No iOS, só podemos buscar dispositivos já conectados, não apenas pareados
        let pairedPeripheralsSPP = centralManager.retrieveConnectedPeripherals(withServices: [printerServiceUUID])
        let pairedPeripheralsAlt = centralManager.retrieveConnectedPeripherals(withServices: [printerServiceUUIDAlt])
        let allPairedPeripherals = pairedPeripheralsSPP + pairedPeripheralsAlt.filter { peripheral in
            !pairedPeripheralsSPP.contains(where: { $0.identifier == peripheral.identifier })
        }
        let pairedMsg = "📱 PrinterHelper: Encontradas \(allPairedPeripherals.count) impressoras já conectadas"
        logger.info("\(pairedMsg)")
        print("\(pairedMsg)")
        availablePrinters.append(contentsOf: allPairedPeripherals)
        
        // Também fazer scan por novas impressoras (sem filtro de serviço para encontrar mais dispositivos)
        let scanMsg = "🔍 PrinterHelper: Iniciando scan por novas impressoras..."
        logger.info("\(scanMsg)")
        print("\(scanMsg)")
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        // Parar scan após 10 segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            self.centralManager?.stopScan()
            self.isScanning = false
            let finalMsg = "✅ PrinterHelper: Scan finalizado. Total de impressoras encontradas: \(self.availablePrinters.count)"
            self.logger.info("\(finalMsg)")
            print("\(finalMsg)")
            
            if self.availablePrinters.isEmpty {
                let noPrinterMsg = "⚠️ PrinterHelper: Nenhuma impressora encontrada. Verifique se a impressora está ligada e próxima ao dispositivo."
                self.logger.warning("\(noPrinterMsg)")
                print("\(noPrinterMsg)")
            } else {
                for (index, printer) in self.availablePrinters.enumerated() {
                    let printerMsg = "   \(index + 1). \(printer.name ?? "Sem nome") - \(printer.identifier)"
                    self.logger.info("\(printerMsg)")
                    print("\(printerMsg)")
                }
            }
        }
    }
    
    func connectToPrinter(_ peripheral: CBPeripheral) {
        logger.info("🔌 PrinterHelper: Tentando conectar à impressora: \(peripheral.name ?? "Sem nome") - \(peripheral.identifier)")
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        printerCharacteristic = nil
        isConnected = false
    }
    
    func printFormattedText(_ text: String, completion: ((Bool, String?) -> Void)? = nil) {
        logger.info("🖨️ PrinterHelper: Tentando imprimir texto...")
        print("🖨️ PrinterHelper: Tentando imprimir texto...")
        
        // Verificar estado detalhado
        let stateMsg = "📊 PrinterHelper: Estado - isConnected: \(isConnected), peripheral: \(connectedPeripheral?.name ?? "nil"), characteristic: \(printerCharacteristic != nil ? "sim" : "nil")"
        logger.info("\(stateMsg)")
        print("\(stateMsg)")
        
        // Verificar se temos periférico conectado (mais confiável que isConnected)
        guard let peripheral = connectedPeripheral else {
            let errorMsg = "Periférico não conectado. Conecte uma impressora primeiro."
            logger.error("❌ PrinterHelper: \(errorMsg)")
            print("❌ PrinterHelper: \(errorMsg)")
            // Atualizar estado se necessário
            if isConnected {
                isConnected = false
            }
            completion?(false, errorMsg)
            return
        }
        
        // Se temos periférico mas isConnected está false, atualizar estado
        if !isConnected && peripheral.state == .connected {
            logger.warning("⚠️ PrinterHelper: Periférico conectado mas isConnected está false. Atualizando estado...")
            print("⚠️ PrinterHelper: Periférico conectado mas isConnected está false. Atualizando estado...")
            isConnected = true
        }
        
        // Verificar se o periférico está realmente conectado
        guard peripheral.state == .connected else {
            let errorMsg = "Periférico não está conectado (estado: \(peripheral.state.rawValue))."
            logger.error("❌ PrinterHelper: \(errorMsg)")
            print("❌ PrinterHelper: \(errorMsg)")
            isConnected = false
            completion?(false, errorMsg)
            return
        }
        
        // Se não temos característica específica, tentar encontrar uma disponível
        if printerCharacteristic == nil {
            logger.warning("⚠️ PrinterHelper: Característica não definida. Procurando características disponíveis...")
            print("⚠️ PrinterHelper: Característica não definida. Procurando características disponíveis...")
            
            // Tentar encontrar qualquer característica disponível nos serviços já descobertos
            if let services = peripheral.services {
                for service in services {
                    if (service.uuid == printerServiceUUID || service.uuid == printerServiceUUIDAlt),
                       let characteristics = service.characteristics, !characteristics.isEmpty {
                        // Usar a primeira característica que permite escrita
                        for char in characteristics {
                            if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                                printerCharacteristic = char
                                logger.info("✅ PrinterHelper: Característica encontrada: \(char.uuid)")
                                print("✅ PrinterHelper: Característica encontrada: \(char.uuid)")
                                break
                            }
                        }
                        // Se não encontrou uma com escrita, usar a primeira disponível
                        if printerCharacteristic == nil, let firstChar = characteristics.first {
                            printerCharacteristic = firstChar
                            logger.info("✅ PrinterHelper: Usando primeira característica disponível: \(firstChar.uuid)")
                            print("✅ PrinterHelper: Usando primeira característica disponível: \(firstChar.uuid)")
                        }
                        if printerCharacteristic != nil {
                            break
                        }
                    }
                }
            }
            
            // Se ainda não encontrou, tentar descobrir características novamente
            if printerCharacteristic == nil {
                logger.warning("⚠️ PrinterHelper: Nenhuma característica encontrada. Tentando descobrir novamente...")
                print("⚠️ PrinterHelper: Nenhuma característica encontrada. Tentando descobrir novamente...")
                
                if let services = peripheral.services {
                    for service in services {
                        if service.uuid == printerServiceUUID || service.uuid == printerServiceUUIDAlt {
                            if service.uuid == printerServiceUUID {
                                peripheral.discoverCharacteristics(nil, for: service)
                            } else {
                                peripheral.discoverCharacteristics([printerCharacteristicUUID, sppCharacteristicUUID1, sppCharacteristicUUID2], for: service)
                            }
                        }
                    }
                }
                
                // Aguardar um pouco para descobrir características
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self = self else { return }
                    // Tentar novamente após descobrir
                    self.attemptPrint(text: text, completion: completion)
                }
                return
            }
        }
        
        attemptPrint(text: text, completion: completion)
    }
    
    private func attemptPrint(text: String, completion: ((Bool, String?) -> Void)?) {
        guard let characteristic = printerCharacteristic else {
            let errorMsg = "Característica da impressora não encontrada. Tente reconectar."
            logger.error("❌ PrinterHelper: \(errorMsg)")
            print("❌ PrinterHelper: \(errorMsg)")
            completion?(false, errorMsg)
            return
        }
        
        logger.info("✅ PrinterHelper: Impressora conectada e pronta. Enviando dados...")
        print("✅ PrinterHelper: Impressora conectada e pronta. Enviando dados...")
        
        // Converter texto para comandos ESC/POS
        let escPosData = convertToEscPos(text)
        logger.info("📄 PrinterHelper: Dados convertidos. Tamanho: \(escPosData.count) bytes")
        print("📄 PrinterHelper: Dados convertidos. Tamanho: \(escPosData.count) bytes")
        
        // Armazenar completion para chamar no callback de escrita
        pendingPrintCompletion = completion
        
        // Enviar dados para impressora
        connectedPeripheral?.writeValue(escPosData, for: characteristic, type: .withResponse)
        logger.info("📤 PrinterHelper: Dados enviados para impressora (aguardando confirmação...)")
        print("📤 PrinterHelper: Dados enviados para impressora (aguardando confirmação...)")
        
        // Para writeWithoutResponse, chamar completion imediatamente
        // Para withResponse, aguardar callback
        if !characteristic.properties.contains(.write) && characteristic.properties.contains(.writeWithoutResponse) {
            // Se só tem writeWithoutResponse, chamar completion após um pequeno delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.pendingPrintCompletion?(true, nil)
                self?.pendingPrintCompletion = nil
            }
        }
        // Se tem write, o completion será chamado no callback didWriteValueFor
    }
    
    func printOrder(_ order: Order, completion: ((Bool, String?) -> Void)? = nil) {
        let orderId = order.displayId ?? order.id
        logger.info("🖨️ PrinterHelper: Imprimindo pedido #\(orderId)")
        print("🖨️ PrinterHelper: Imprimindo pedido #\(orderId)")
        
        // Log do estado inicial
        let initialStateMsg = "📊 PrinterHelper.printOrder: Estado inicial - isConnected: \(isConnected), peripheral: \(connectedPeripheral?.name ?? "nil"), state: \(connectedPeripheral?.state.rawValue ?? -1), characteristic: \(printerCharacteristic != nil ? "sim" : "nil")"
        logger.info("\(initialStateMsg)")
        print("\(initialStateMsg)")
        
        // Verificar e atualizar estado de conexão antes de imprimir
        if let peripheral = connectedPeripheral, peripheral.state == .connected {
            if !isConnected {
                logger.warning("⚠️ PrinterHelper: Periférico conectado mas isConnected está false. Atualizando estado...")
                print("⚠️ PrinterHelper: Periférico conectado mas isConnected está false. Atualizando estado...")
                isConnected = true
            }
            // Se não temos característica mas temos periférico conectado, tentar encontrar
            if printerCharacteristic == nil {
                logger.warning("⚠️ PrinterHelper: Característica não definida. Procurando nas características já descobertas...")
                print("⚠️ PrinterHelper: Característica não definida. Procurando nas características já descobertas...")
                if let services = peripheral.services {
                    for service in services {
                        if (service.uuid == printerServiceUUID || service.uuid == printerServiceUUIDAlt),
                           let characteristics = service.characteristics, !characteristics.isEmpty {
                            for char in characteristics {
                                if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                                    printerCharacteristic = char
                                    logger.info("✅ PrinterHelper: Característica encontrada: \(char.uuid)")
                                    print("✅ PrinterHelper: Característica encontrada: \(char.uuid)")
                                    break
                                }
                            }
                            if printerCharacteristic == nil, let firstChar = characteristics.first {
                                printerCharacteristic = firstChar
                                logger.info("✅ PrinterHelper: Usando primeira característica disponível: \(firstChar.uuid)")
                                print("✅ PrinterHelper: Usando primeira característica disponível: \(firstChar.uuid)")
                            }
                            if printerCharacteristic != nil {
                                break
                            }
                        }
                    }
                }
            }
        }
        
        // Log do estado após verificação
        let finalStateMsg = "📊 PrinterHelper.printOrder: Estado após verificação - isConnected: \(isConnected), peripheral: \(connectedPeripheral?.name ?? "nil"), state: \(connectedPeripheral?.state.rawValue ?? -1), characteristic: \(printerCharacteristic != nil ? "sim" : "nil")"
        logger.info("\(finalStateMsg)")
        print("\(finalStateMsg)")
        
        let orderText = formatOrder(order)
        print("📝 PrinterHelper.printOrder: Texto formatado (\(orderText.count) caracteres), chamando printFormattedText...")
        printFormattedText(orderText, completion: completion)
    }
    
    func testPrint() {
        logger.info("🖨️ PrinterHelper: Iniciando teste de impressão...")
        print("🖨️ PrinterHelper: Iniciando teste de impressão...")
        
        // Verificar e atualizar estado de conexão antes de imprimir (igual ao printOrder)
        if let peripheral = connectedPeripheral, peripheral.state == .connected {
            if !isConnected {
                logger.warning("⚠️ PrinterHelper: Periférico conectado mas isConnected está false. Atualizando estado...")
                print("⚠️ PrinterHelper: Periférico conectado mas isConnected está false. Atualizando estado...")
                isConnected = true
            }
            // Se não temos característica mas temos periférico conectado, tentar encontrar
            if printerCharacteristic == nil {
                logger.warning("⚠️ PrinterHelper: Característica não definida. Procurando nas características já descobertas...")
                print("⚠️ PrinterHelper: Característica não definida. Procurando nas características já descobertas...")
                if let services = peripheral.services {
                    for service in services {
                        if (service.uuid == printerServiceUUID || service.uuid == printerServiceUUIDAlt),
                           let characteristics = service.characteristics, !characteristics.isEmpty {
                            for char in characteristics {
                                if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                                    printerCharacteristic = char
                                    logger.info("✅ PrinterHelper: Característica encontrada: \(char.uuid)")
                                    print("✅ PrinterHelper: Característica encontrada: \(char.uuid)")
                                    break
                                }
                            }
                            if printerCharacteristic == nil, let firstChar = characteristics.first {
                                printerCharacteristic = firstChar
                                logger.info("✅ PrinterHelper: Usando primeira característica disponível: \(firstChar.uuid)")
                                print("✅ PrinterHelper: Usando primeira característica disponível: \(firstChar.uuid)")
                            }
                            if printerCharacteristic != nil {
                                break
                            }
                        }
                    }
                }
            }
        }
        
        let testText = """
            [C]<b>TESTE DE IMPRESSÃO</b>
            [C]Pedidos Express
            [C]----------------
            [L]
            [L]Produto: Hambúrguer
            [L]Quantidade: 1
            [L]Preço: R$ 25,00
            [L]
            [C]----------------
            [L]
            [C]Obrigado!
        """
        printFormattedText(testText)
    }
    
    /// Remove "Hambúrguer" ou "Hamburguer" do início do nome do produto
    private func removeHamburguerPrefix(_ productName: String) -> String {
        // Usar regex case-insensitive para remover "Hambúrguer" ou "Hamburguer" do início
        let pattern = "^[Hh]amb[uú]rguer\\s+"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: productName.utf16.count)
            let result = regex.stringByReplacingMatches(in: productName, options: [], range: range, withTemplate: "")
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return productName
    }
    
    private func formatOrder(_ order: Order) -> String {
        // Usar displayId se disponível, senão usar os primeiros 8 caracteres do ID
        // Limpar qualquer caractere especial que possa estar no displayId
        let displayId: String
        if let orderDisplayId = order.displayId, !orderDisplayId.isEmpty {
            // Remover caracteres especiais e espaços extras, manter apenas alfanuméricos e hífen
            displayId = orderDisplayId.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            displayId = String(order.id.prefix(8))
        }
        
        // Converter data para horário Brasil (GMT-3)
        let timeStr: String
        if let date = parseDate(order.createdAt) {
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
            formatter.dateFormat = "HH:mm"
            timeStr = formatter.string(from: date)
        } else {
            timeStr = String(order.createdAt.prefix(5))
        }
        
        // Determinar endereço ou tipo de pedido
        let addressInfo: String
        if let deliveryAddress = order.deliveryAddress, !deliveryAddress.isEmpty {
            addressInfo = "End: \(deliveryAddress)"
        } else if order.orderType == "dine_in" || order.orderType == "restaurant" {
            addressInfo = "Comer no restaurante"
        } else {
            addressInfo = "Comer no restaurante"
        }
        
        // Formatar texto igual ao Kotlin
        // Usar tags que são convertidas para ESC/POS: [C], [L], <b>, </b>, <font size='big'>, </font>
        var orderText = "[C]<b>PEDIDO #\(displayId)</b>\n\n"
        orderText += "[L]Cliente: \(order.customerPhone)\n"
        orderText += "[L]Horário: \(timeStr)\n"
        orderText += "[L]\(addressInfo)\n\n"
        orderText += "[L]<font size='big'><b>ITENS:</b></font>\n"
        
        for item in order.items {
            let productName = removeHamburguerPrefix(item.name)
            orderText += "[L]<font size='big'>\(item.quantity)x \(productName)</font>\n"
        }
        
        orderText += "\n\n"
        
        return orderText
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: dateString)
    }
    
    private func convertToEscPos(_ text: String) -> Data {
        var data = Data()
        
        // Inicializar impressora
        data.append(ESC_POS_INIT)
        
        // Comandos ESC/POS para fonte dupla altura e largura
        // ESC ! n onde n = 0x30 (48) = altura dupla (bit 4) + largura dupla (bit 5)
        let doubleSizeOn = "\u{1B}!\u{30}" // ESC ! 0x30
        let doubleSizeOff = "\u{1B}!\u{00}" // ESC ! 0x00 (normal)
        
        // Processar tags de formatação
        var currentText = text
        
        // Processar alinhamento primeiro
        currentText = currentText.replacingOccurrences(of: "[C]", with: "\u{1B}a1") // Centralizar
        currentText = currentText.replacingOccurrences(of: "[L]", with: "\u{1B}a0") // Alinhar à esquerda
        
        // Processar tags de fonte maior: substituir <font size='big'> por comando ESC/POS
        currentText = currentText.replacingOccurrences(of: "<font size='big'>", with: doubleSizeOn, options: .caseInsensitive)
        currentText = currentText.replacingOccurrences(of: "</font>", with: doubleSizeOff, options: .caseInsensitive)
        
        // Processar tags de negrito
        currentText = currentText.replacingOccurrences(of: "<b>", with: "\u{1B}E1") // Negrito ON
        currentText = currentText.replacingOccurrences(of: "</b>", with: "\u{1B}E0") // Negrito OFF
        
        // Adicionar texto convertido
        if let textData = currentText.data(using: .utf8) {
            data.append(textData)
        }
        
        // Cortar papel
        data.append(ESC_POS_CUT)
        
        return data
    }
}

// Comandos ESC/POS básicos
private let ESC_POS_INIT: Data = {
    var data = Data()
    data.append(0x1B) // ESC
    data.append(0x40) // @ (Inicializar)
    return data
}()

private let ESC_POS_CUT: Data = {
    var data = Data()
    data.append(0x1D) // GS
    data.append(0x56) // V
    data.append(0x00) // Corte parcial
    return data
}()

// MARK: - CBCentralManagerDelegate
extension PrinterHelper: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            logger.info("✅ PrinterHelper: Bluetooth ligado")
            // Não fazer scan automático aqui, apenas quando solicitado pelo usuário
        case .poweredOff:
            logger.error("❌ PrinterHelper: Bluetooth desligado")
            isConnected = false
        case .unauthorized:
            logger.error("❌ PrinterHelper: Bluetooth não autorizado")
        case .unsupported:
            logger.error("❌ PrinterHelper: Bluetooth não suportado")
        case .resetting:
            logger.warning("⚠️ PrinterHelper: Bluetooth resetando")
        @unknown default:
            logger.warning("⚠️ PrinterHelper: Estado desconhecido: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Sem nome"
        let logMsg = "🔍 PrinterHelper: Dispositivo encontrado: \(name) - RSSI: \(RSSI)"
        logger.info("\(logMsg)")
        print("\(logMsg)") // Sempre mostrar no console
        
        // Verificar se tem o serviço UUID de impressora nos dados de anúncio
        var hasPrinterService = false
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            // Verificar tanto o UUID SPP padrão quanto o alternativo
            hasPrinterService = serviceUUIDs.contains { uuid in
                uuid == printerServiceUUID || uuid == printerServiceUUIDAlt
            }
            if hasPrinterService {
                let msg = "✅ PrinterHelper: Dispositivo \(name) tem serviço de impressora UUID (SPP ou alternativo)"
                logger.info("\(msg)")
                print("\(msg)")
            }
        }
        
        // Filtrar apenas impressoras (geralmente têm "printer", "POS", "thermal" no nome)
        // OU se tiver o serviço UUID específico
        let nameLower = name.lowercased()
        let isPrinterName = nameLower.contains("printer") ||
                           nameLower.contains("pos") ||
                           nameLower.contains("thermal") ||
                           nameLower.contains("impressora") ||
                           nameLower.contains("print") ||
                           nameLower.contains("epson") ||
                           nameLower.contains("star") ||
                           nameLower.contains("bixolon") ||
                           nameLower.contains("zebra") ||
                           nameLower.contains("mpt") ||  // MPT-II impressora
                           nameLower.contains("mpt-ii") ||
                           nameLower.contains("mpt-2")
        
        // Adicionar se for impressora por nome OU se tiver o serviço UUID
        if isPrinterName || hasPrinterService {
            if !availablePrinters.contains(where: { $0.identifier == peripheral.identifier }) {
                let msg = "✅ PrinterHelper: Adicionando impressora: \(name)"
                logger.info("\(msg)")
                print("\(msg)")
                availablePrinters.append(peripheral)
            } else {
                let msg = "ℹ️ PrinterHelper: Impressora \(name) já está na lista"
                logger.info("\(msg)")
                print("\(msg)")
            }
        } else {
            // Log de debug para ver TODOS os dispositivos encontrados
            let msg = "⏭️ PrinterHelper: Ignorando dispositivo '\(name)' (não parece ser impressora)"
            logger.debug("\(msg)")
            print("\(msg)") // Mostrar todos para debug
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let msg = "✅ PrinterHelper: Conectado à impressora: \(peripheral.name ?? "Sem nome")"
        logger.info("\(msg)")
        print("\(msg)")
        isConnected = true
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        let stateMsg = "📊 PrinterHelper: Estado atualizado - isConnected = \(isConnected), peripheral: \(peripheral.name ?? "nil")"
        logger.info("\(stateMsg)")
        print("\(stateMsg)")
        // Descobrir ambos os serviços (SPP padrão e alternativo)
        peripheral.discoverServices([printerServiceUUID, printerServiceUUIDAlt])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            logger.error("❌ PrinterHelper: Desconectado com erro: \(error.localizedDescription)")
            print("❌ PrinterHelper: Desconectado com erro: \(error.localizedDescription)")
        } else {
            logger.info("ℹ️ PrinterHelper: Desconectado da impressora")
            print("ℹ️ PrinterHelper: Desconectado da impressora")
        }
        // Só limpar se for o mesmo periférico que estava conectado
        if connectedPeripheral?.identifier == peripheral.identifier {
            isConnected = false
            printerCharacteristic = nil
            let stateMsg = "📊 PrinterHelper: Estado limpo após desconexão - isConnected = \(isConnected)"
            logger.info("\(stateMsg)")
            print("\(stateMsg)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let errorMsg = error?.localizedDescription ?? "Desconhecido"
        logger.error("❌ PrinterHelper: Falha ao conectar: \(errorMsg)")
        isConnected = false
    }
}

// MARK: - CBPeripheralDelegate
extension PrinterHelper: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("❌ PrinterHelper: Erro ao descobrir serviços: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            logger.warning("⚠️ PrinterHelper: Nenhum serviço encontrado")
            return
        }
        
        logger.info("✅ PrinterHelper: \(services.count) serviço(s) encontrado(s)")
        print("✅ PrinterHelper: \(services.count) serviço(s) encontrado(s)")
        for service in services {
            let serviceMsg = "   - Serviço: \(service.uuid)"
            logger.info("\(serviceMsg)")
            print("\(serviceMsg)")
            // Verificar tanto o UUID SPP padrão quanto o alternativo
            if service.uuid == printerServiceUUID || service.uuid == printerServiceUUIDAlt {
                let foundMsg = "✅ PrinterHelper: Serviço de impressora encontrado! Buscando características..."
                logger.info("\(foundMsg)")
                print("\(foundMsg)")
                // Para SPP padrão, pode não ter características específicas, usar todas disponíveis
                if service.uuid == printerServiceUUID {
                    // SPP padrão - descobrir todas as características
                    peripheral.discoverCharacteristics(nil, for: service)
                } else {
                    // UUID alternativo - usar a característica específica
                    peripheral.discoverCharacteristics([printerCharacteristicUUID], for: service)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            logger.error("❌ PrinterHelper: Erro ao descobrir características: \(error.localizedDescription)")
            return
        }
        
        // Para SPP padrão (printerServiceUUID), pode não ter características específicas
        // Nesse caso, podemos usar o serviço diretamente
        if service.uuid == printerServiceUUID {
            guard let characteristics = service.characteristics else {
                logger.warning("⚠️ PrinterHelper: Nenhuma característica encontrada para SPP padrão")
                print("⚠️ PrinterHelper: Nenhuma característica encontrada para SPP padrão")
                return
            }
            
            if !characteristics.isEmpty {
                logger.info("✅ PrinterHelper: SPP padrão - \(characteristics.count) característica(s) encontrada(s)")
                print("✅ PrinterHelper: SPP padrão - \(characteristics.count) característica(s) encontrada(s)")
                // Usar a primeira característica disponível ou a que permite escrita
                for characteristic in characteristics {
                    let charMsg = "   - Característica: \(characteristic.uuid)"
                    logger.info("\(charMsg)")
                    print("\(charMsg)")
                    // Verificar se é uma característica padrão do SPP ou permite escrita
                    if characteristic.uuid == sppCharacteristicUUID1 || 
                       characteristic.uuid == sppCharacteristicUUID2 ||
                       characteristic.properties.contains(.write) || 
                       characteristic.properties.contains(.writeWithoutResponse) {
                        let readyMsg = "✅ PrinterHelper: Característica de escrita encontrada! Impressora pronta."
                        logger.info("\(readyMsg)")
                        print("\(readyMsg)")
                        printerCharacteristic = characteristic
                        // Garantir que isConnected está true
                        if !isConnected {
                            isConnected = true
                            logger.info("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                            print("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                        }
                        break
                    }
                }
                // Se não encontrou uma com escrita ou padrão do SPP, usar a primeira
                if printerCharacteristic == nil, let firstChar = characteristics.first {
                    let fallbackMsg = "   Usando primeira característica disponível: \(firstChar.uuid)"
                    logger.info("\(fallbackMsg)")
                    print("\(fallbackMsg)")
                    printerCharacteristic = firstChar
                    // Garantir que isConnected está true
                    if !isConnected {
                        isConnected = true
                        logger.info("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                        print("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                    }
                } else if printerCharacteristic != nil {
                    // Garantir que isConnected está true quando temos característica
                    if !isConnected {
                        isConnected = true
                        logger.info("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                        print("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                    }
                }
            } else {
                // SPP padrão sem características - isso pode acontecer
                // Vamos tentar descobrir características padrão do SPP
                logger.info("✅ PrinterHelper: SPP padrão sem características específicas. Tentando descobrir características padrão do SPP...")
                print("✅ PrinterHelper: SPP padrão sem características específicas. Tentando descobrir características padrão do SPP...")
                // Tentar descobrir características padrão do SPP
                peripheral.discoverCharacteristics([sppCharacteristicUUID1, sppCharacteristicUUID2], for: service)
                // O callback didDiscoverCharacteristicsFor será chamado novamente quando encontrar
                // Por enquanto, marcar como conectado se ainda não estiver
                if !isConnected {
                    isConnected = true
                    logger.info("✅ PrinterHelper: Estado de conexão atualizado para conectado (aguardando características)")
                    print("✅ PrinterHelper: Estado de conexão atualizado para conectado (aguardando características)")
                }
            }
            return // Retornar aqui para não processar novamente abaixo
        }
        
        // Para UUID alternativo, usar a lógica original
        guard let characteristics = service.characteristics else {
            logger.warning("⚠️ PrinterHelper: Nenhuma característica encontrada")
            print("⚠️ PrinterHelper: Nenhuma característica encontrada")
            return
        }
        
        logger.info("✅ PrinterHelper: \(characteristics.count) característica(s) encontrada(s)")
        print("✅ PrinterHelper: \(characteristics.count) característica(s) encontrada(s)")
        for characteristic in characteristics {
            let charMsg = "   - Característica: \(characteristic.uuid)"
            logger.info("\(charMsg)")
            print("\(charMsg)")
            // Verificar UUID específico OU características padrão do SPP
            if characteristic.uuid == printerCharacteristicUUID || 
               characteristic.uuid == sppCharacteristicUUID1 || 
               characteristic.uuid == sppCharacteristicUUID2 {
                let readyMsg = "✅ PrinterHelper: Característica de impressão encontrada! Impressora pronta."
                logger.info("\(readyMsg)")
                print("\(readyMsg)")
                printerCharacteristic = characteristic
                // Garantir que isConnected está true
                if !isConnected {
                    isConnected = true
                    logger.info("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                    print("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                }
                break
            }
        }
        
        if printerCharacteristic == nil {
            logger.warning("⚠️ PrinterHelper: Característica de impressão não encontrada. Tentando usar primeira característica disponível...")
            print("⚠️ PrinterHelper: Característica de impressão não encontrada. Tentando usar primeira característica disponível...")
            // Tentar encontrar uma característica que permite escrita
            for characteristic in characteristics {
                if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                    let usingMsg = "   Usando característica com escrita: \(characteristic.uuid)"
                    logger.info("\(usingMsg)")
                    print("\(usingMsg)")
                    printerCharacteristic = characteristic
                    // Garantir que isConnected está true
                    if !isConnected {
                        isConnected = true
                        logger.info("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                        print("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                    }
                    break
                }
            }
            // Se ainda não encontrou, usar a primeira disponível
            if printerCharacteristic == nil, let firstChar = characteristics.first {
                let usingMsg = "   Usando primeira característica disponível: \(firstChar.uuid)"
                logger.info("\(usingMsg)")
                print("\(usingMsg)")
                printerCharacteristic = firstChar
                // Garantir que isConnected está true
                if !isConnected {
                    isConnected = true
                    logger.info("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                    print("✅ PrinterHelper: Estado de conexão atualizado para conectado")
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            let errorMsg = "Erro ao escrever dados na impressora: \(error.localizedDescription)"
            logger.error("❌ PrinterHelper: \(errorMsg)")
            print("❌ PrinterHelper: \(errorMsg)")
            pendingPrintCompletion?(false, errorMsg)
        } else {
            let successMsg = "✅ PrinterHelper: Dados escritos com sucesso na impressora"
            logger.info("\(successMsg)")
            print("\(successMsg)")
            pendingPrintCompletion?(true, nil)
        }
        pendingPrintCompletion = nil
    }
}
