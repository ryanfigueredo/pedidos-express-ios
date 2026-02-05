import Foundation

/**
 * Helper para obter labels dinâmicos baseados no tipo de negócio
 */
class BusinessTypeHelper {
    static func getLabel(for user: User?, defaultLabel: String, dentistaLabel: String) -> String {
        guard let user = user else {
            return defaultLabel
        }
        return user.isDentista ? dentistaLabel : defaultLabel
    }
    
    // Labels principais
    static func ordersLabel(for user: User?) -> String {
        return getLabel(for: user, defaultLabel: "Pedidos", dentistaLabel: "Agendamentos")
    }
    
    static func menuLabel(for user: User?) -> String {
        return getLabel(for: user, defaultLabel: "Cardápio", dentistaLabel: "Procedimentos")
    }
    
    static func orderLabel(for user: User?) -> String {
        return getLabel(for: user, defaultLabel: "Pedido", dentistaLabel: "Agendamento")
    }
    
    static func ordersTodayLabel(for user: User?) -> String {
        return getLabel(for: user, defaultLabel: "Pedidos Hoje", dentistaLabel: "Agendamentos Hoje")
    }
    
    static func itemsLabel(for user: User?) -> String {
        return getLabel(for: user, defaultLabel: "Itens", dentistaLabel: "Procedimentos")
    }
    
    static func itemLabel(for user: User?) -> String {
        return getLabel(for: user, defaultLabel: "Item", dentistaLabel: "Procedimento")
    }
    
    // Labels para segmentos
    static func pendingOrdersLabel(for user: User?) -> String {
        return getLabel(for: user, defaultLabel: "Pedidos", dentistaLabel: "Agendamentos")
    }
    
    static func outForDeliveryLabel(for user: User?) -> String {
        return getLabel(for: user, defaultLabel: "Rota", dentistaLabel: "Confirmados")
    }
    
    static func finishedOrdersLabel(for user: User?) -> String {
        return getLabel(for: user, defaultLabel: "Entregues", dentistaLabel: "Concluídos")
    }
}
