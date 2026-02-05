# Pedidos Express - iOS App

Aplicativo iOS nativo desenvolvido em Swift para o sistema Pedidos Express, permitindo que restaurantes gerenciem pedidos, cardápio e impressão de recibos.

## 📱 Sobre o Projeto

Este é o aplicativo iOS do Pedidos Express, uma plataforma completa de gestão de pedidos para restaurantes. O app permite:

- 📋 Visualização e gerenciamento de pedidos em tempo real
- 🍔 Gerenciamento de cardápio e itens
- 🖨️ Impressão de recibos via impressoras térmicas
- 📊 Dashboard com estatísticas e métricas
- ⚙️ Configurações da loja
- 💬 Suporte integrado

## 🛠️ Tecnologias

- **Linguagem**: Swift 5.9+
- **Plataforma**: iOS 15.0+
- **Framework**: UIKit
- **Arquitetura**: MVC (Model-View-Controller)
- **Gerenciador de Dependências**: Swift Package Manager

## 📦 Estrutura do Projeto

```
app-swift/
├── PedidosExpress/
│   ├── AppDelegate.swift              # Delegate principal
│   ├── SceneDelegate.swift            # Gerenciamento de cenas
│   ├── Models/                        # Modelos de dados
│   │   ├── User.swift
│   │   ├── Order.swift
│   │   ├── MenuItem.swift
│   │   └── Dashboard.swift
│   ├── Services/                      # Serviços
│   │   ├── ApiService.swift           # Serviço de API
│   │   ├── AuthService.swift          # Autenticação
│   │   └── PrinterHelper.swift        # Helper de impressão
│   ├── ViewControllers/               # Controllers
│   │   ├── LoginViewController.swift
│   │   ├── MainNavigationViewController.swift
│   │   ├── DashboardViewController.swift
│   │   ├── OrdersViewController.swift
│   │   ├── MenuViewController.swift
│   │   ├── SettingsViewController.swift
│   │   └── SupportViewController.swift
│   ├── Views/                         # Views customizadas
│   │   ├── MenuItemTableViewCell.swift
│   │   └── OrderTableViewCell.swift
│   └── Resources/                     # Recursos
│       ├── Assets.xcassets/           # Imagens e ícones
│       ├── Main.storyboard
│       └── LaunchScreen.storyboard
└── PedidosExpress.xcodeproj/         # Projeto Xcode
```

## 🚀 Como Executar

### Pré-requisitos

- macOS com Xcode 15.0 ou superior
- iOS Simulator ou dispositivo físico iOS 15.0+
- CocoaPods (se houver dependências externas)

### Instalação

1. Clone o repositório:
```bash
git clone https://github.com/ryanfigueredo/pedidos-express-ios.git
cd pedidos-express-ios
```

2. Abra o projeto no Xcode:
```bash
open PedidosExpress.xcodeproj
```

3. Configure o Team de desenvolvimento:
   - Selecione o projeto no navegador
   - Vá em "Signing & Capabilities"
   - Selecione seu Team de desenvolvimento

4. Selecione um dispositivo ou simulador:
   - Escolha um dispositivo no seletor de dispositivos no topo do Xcode

5. Execute o app:
   - Pressione `Cmd + R` ou clique no botão "Run"

### Build de Release

1. Selecione o esquema "Release" no Xcode
2. Product → Archive
3. Siga o processo de distribuição (App Store, TestFlight, ou Ad Hoc)

## 🔧 Configuração

### API Endpoint

Configure a URL da API no arquivo `ApiService.swift`:

```swift
private let baseURL = "https://sua-api.com/api"
```

### Autenticação

O app utiliza autenticação via token JWT. As credenciais são armazenadas localmente usando UserDefaults ou Keychain.

## 📱 Funcionalidades

### Dashboard
- Visualização de pedidos pendentes
- Estatísticas de vendas
- Status da loja (aberta/fechada)

### Pedidos
- Lista de pedidos em tempo real
- Filtros por status
- Detalhes do pedido
- Marcação de impresso/enviado

### Cardápio
- Visualização de itens
- Edição de preços e disponibilidade
- Categorias

### Impressão
- Suporte para impressoras térmicas
- Impressão de recibos de pedidos
- Configuração de impressora

## 🔐 Segurança

- Credenciais armazenadas no Keychain
- Comunicação HTTPS com a API
- Validação de tokens JWT
- App Transport Security configurado

## 📄 Licença

Este projeto é privado e proprietário.

## 👥 Contribuição

Este é um projeto privado. Para questões ou sugestões, entre em contato com a equipe de desenvolvimento.

## 📞 Suporte

Para suporte técnico, abra uma issue no repositório ou entre em contato através do app na seção "Suporte".

## 🍎 Requisitos do iOS

- iOS 15.0 ou superior
- iPhone ou iPad compatível
- Conexão com internet para sincronização

---

**Versão**: 1.0.0  
**Última atualização**: 2025
