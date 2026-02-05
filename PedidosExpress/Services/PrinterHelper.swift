import Foundation
import CoreBluetooth
import os.log

class PrinterHelper: NSObject, ObservableObject {
    private var centralManager: CBCentralManager?
    var connectedPeripheral: CBPeripheral?
    private var printerCharacteristic: CBCharacteristic?
    
    @Published var isConnected = false
    @Published var availablePrinters: [CBPeripheral] = []
    @Published var isScanning = false
    
    // UUID padrão SPP (Serial Port Profile) usado pela maioria das impressoras Bluetooth
    // Este é o mesmo UUID usado pelo Android: 00001101-0000-1000-8000-00805f9b34fb
    private let printerServiceUUID = CBUUID(string: "00001101-0000-1000-8000-00805f9b34fb")
    // UUID alternativo usado por algumas impressoras
    private let printerServiceUUIDAlt = CBUUID(string: "0000ff00-0000-1000-8000-00805f9b34fb")
    private let printerCharacteristicUUID = CBUUID(string: "0000ff02-0000-1000-8000-00805f9b34fb")
    
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
        
        guard isConnected else {
            let errorMsg = "Impressora não conectada. Conecte uma impressora primeiro."
            logger.error("❌ PrinterHelper: \(errorMsg)")
            completion?(false, errorMsg)
            return
        }
        
        guard let characteristic = printerCharacteristic else {
            let errorMsg = "Característica da impressora não encontrada. Tente reconectar."
            logger.error("❌ PrinterHelper: \(errorMsg)")
            completion?(false, errorMsg)
            return
        }
        
        logger.info("✅ PrinterHelper: Impressora conectada e pronta. Enviando dados...")
        
        // Converter texto para comandos ESC/POS
        let escPosData = convertToEscPos(text)
        logger.info("📄 PrinterHelper: Dados convertidos. Tamanho: \(escPosData.count) bytes")
        
        connectedPeripheral?.writeValue(escPosData, for: characteristic, type: .withResponse)
        logger.info("✅ PrinterHelper: Dados enviados para impressora")
        completion?(true, nil)
    }
    
    func printOrder(_ order: Order, completion: ((Bool, String?) -> Void)? = nil) {
        logger.info("🖨️ PrinterHelper: Imprimindo pedido #\(order.displayId ?? order.id)")
        let orderText = formatOrder(order)
        printFormattedText(orderText, completion: completion)
    }
    
    func testPrint() {
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
    
    private func formatOrder(_ order: Order) -> String {
        let displayId = order.displayId ?? String(order.id.prefix(8))
        
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
        
        var orderText = "[C]<b>PEDIDO #\(displayId)</b>\n\n"
        orderText += "[L]Cliente: \(order.customerPhone)\n"
        orderText += "[L]Horário: \(timeStr)\n"
        orderText += "[L]\(addressInfo)\n\n"
        orderText += "[L]<font size='big'><b>ITENS:</b></font>\n"
        
        for item in order.items {
            orderText += "[L]<font size='big'>\(item.quantity)x \(item.name)</font>\n"
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
        
        // Processar tags de formatação
        var currentText = text
        currentText = currentText.replacingOccurrences(of: "[C]", with: "\u{1B}a1") // Centralizar
        currentText = currentText.replacingOccurrences(of: "[L]", with: "\u{1B}a0") // Alinhar à esquerda
        currentText = currentText.replacingOccurrences(of: "<b>", with: "\u{1B}E1") // Negrito ON
        currentText = currentText.replacingOccurrences(of: "</b>", with: "\u{1B}E0") // Negrito OFF
        
        // Adicionar texto
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
        // Descobrir ambos os serviços (SPP padrão e alternativo)
        peripheral.discoverServices([printerServiceUUID, printerServiceUUIDAlt])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            logger.error("❌ PrinterHelper: Desconectado com erro: \(error.localizedDescription)")
        } else {
            logger.info("ℹ️ PrinterHelper: Desconectado da impressora")
        }
        isConnected = false
        printerCharacteristic = nil
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
        for service in services {
            logger.info("   - Serviço: \(service.uuid)")
            // Verificar tanto o UUID SPP padrão quanto o alternativo
            if service.uuid == printerServiceUUID || service.uuid == printerServiceUUIDAlt {
                logger.info("✅ PrinterHelper: Serviço de impressora encontrado! Buscando características...")
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
            if let characteristics = service.characteristics, !characteristics.isEmpty {
                logger.info("✅ PrinterHelper: SPP padrão - \(characteristics.count) característica(s) encontrada(s)")
                // Usar a primeira característica disponível ou a que permite escrita
                for characteristic in characteristics {
                    logger.info("   - Característica: \(characteristic.uuid)")
                    if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                        logger.info("✅ PrinterHelper: Característica de escrita encontrada! Impressora pronta.")
                        printerCharacteristic = characteristic
                        break
                    }
                }
                // Se não encontrou uma com escrita, usar a primeira
                if printerCharacteristic == nil, let firstChar = characteristics.first {
                    logger.info("   Usando primeira característica disponível: \(firstChar.uuid)")
                    printerCharacteristic = firstChar
                }
            } else {
                // SPP padrão sem características - isso é normal, vamos tentar usar o serviço diretamente
                logger.info("✅ PrinterHelper: SPP padrão sem características específicas (normal para SPP)")
                // Vamos marcar como pronto mesmo sem característica específica
                // A escrita será feita diretamente no serviço
            }
            return
        }
        
        // Para UUID alternativo, usar a lógica original
        guard let characteristics = service.characteristics else {
            logger.warning("⚠️ PrinterHelper: Nenhuma característica encontrada")
            return
        }
        
        logger.info("✅ PrinterHelper: \(characteristics.count) característica(s) encontrada(s)")
        for characteristic in characteristics {
            logger.info("   - Característica: \(characteristic.uuid)")
            if characteristic.uuid == printerCharacteristicUUID {
                logger.info("✅ PrinterHelper: Característica de impressão encontrada! Impressora pronta.")
                printerCharacteristic = characteristic
                break
            }
        }
        
        if printerCharacteristic == nil {
            logger.warning("⚠️ PrinterHelper: Característica de impressão não encontrada. Tentando usar primeira característica disponível...")
            if let firstChar = characteristics.first {
                logger.info("   Usando: \(firstChar.uuid)")
                printerCharacteristic = firstChar
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("❌ PrinterHelper: Erro ao escrever dados: \(error.localizedDescription)")
        } else {
            logger.info("✅ PrinterHelper: Dados escritos com sucesso na impressora")
        }
    }
}
