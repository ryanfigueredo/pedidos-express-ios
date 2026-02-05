import Foundation
import CoreBluetooth

class PrinterHelper: NSObject, ObservableObject {
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var printerCharacteristic: CBCharacteristic?
    
    @Published var isConnected = false
    @Published var availablePrinters: [CBPeripheral] = []
    
    private let printerServiceUUID = CBUUID(string: "0000ff00-0000-1000-8000-00805f9b34fb")
    private let printerCharacteristicUUID = CBUUID(string: "0000ff02-0000-1000-8000-00805f9b34fb")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func scanForPrinters() {
        guard let centralManager = centralManager,
              centralManager.state == .poweredOn else {
            return
        }
        
        // Buscar impressoras pareadas
        let pairedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [printerServiceUUID])
        availablePrinters = pairedPeripherals
        
        // Também fazer scan por novas impressoras
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        // Parar scan após 5 segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.centralManager?.stopScan()
        }
    }
    
    func connectToPrinter(_ peripheral: CBPeripheral) {
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
        guard isConnected, let characteristic = printerCharacteristic else {
            completion?(false, "Impressora não conectada")
            return
        }
        
        // Converter texto para comandos ESC/POS
        let escPosData = convertToEscPos(text)
        
        connectedPeripheral?.writeValue(escPosData, for: characteristic, type: .withResponse)
        completion?(true, nil)
    }
    
    func printOrder(_ order: Order) {
        let orderText = formatOrder(order)
        printFormattedText(orderText)
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
            scanForPrinters()
        case .poweredOff:
            isConnected = false
        case .unauthorized:
            print("Bluetooth não autorizado")
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Filtrar apenas impressoras (geralmente têm "printer" ou "POS" no nome)
        let name = peripheral.name ?? ""
        if name.lowercased().contains("printer") ||
           name.lowercased().contains("pos") ||
           name.lowercased().contains("thermal") {
            if !availablePrinters.contains(where: { $0.identifier == peripheral.identifier }) {
                availablePrinters.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.discoverServices([printerServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        printerCharacteristic = nil
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        print("Falha ao conectar: \(error?.localizedDescription ?? "Desconhecido")")
    }
}

// MARK: - CBPeripheralDelegate
extension PrinterHelper: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == printerServiceUUID {
                peripheral.discoverCharacteristics([printerCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == printerCharacteristicUUID {
                printerCharacteristic = characteristic
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Erro ao escrever: \(error.localizedDescription)")
        }
    }
}
