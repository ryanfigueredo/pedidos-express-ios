import UIKit

class SupportViewController: UIViewController {
    private var conversationsTableView: UITableView!
    private var progressIndicator: UIActivityIndicatorView!
    
    private let apiService = ApiService()
    private var conversations: [PriorityConversation] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Suporte"
        navigationItem.largeTitleDisplayMode = .never
        setupUI()
        setupTableView()
        loadConversations()
    }
    
    private func setupUI() {
        view.backgroundColor = .pedidosOrangeLight
        
        conversationsTableView = UITableView()
        conversationsTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(conversationsTableView)
        
        progressIndicator = UIActivityIndicatorView(style: .large)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.hidesWhenStopped = true
        view.addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            conversationsTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            conversationsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            conversationsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            conversationsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadConversations()
    }
    
    private func setupTableView() {
        conversationsTableView.delegate = self
        conversationsTableView.dataSource = self
        conversationsTableView.backgroundColor = .pedidosOrangeLight
        conversationsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ConversationCell")
    }
    
    private func loadConversations() {
        progressIndicator.startAnimating()
        
        Task {
            do {
                let convs = try await apiService.getPriorityConversations()
                
                #if DEBUG
                print("💬 SupportViewController: Recebidas \(convs.count) conversas prioritárias")
                #endif
                
                await MainActor.run {
                    self.conversations = convs
                    self.conversationsTableView.reloadData()
                    self.progressIndicator.stopAnimating()
                    
                    // Remover label de vazio anterior se existir
                    self.view.subviews.forEach { subview in
                        if subview is UILabel && subview.tag == 999 {
                            subview.removeFromSuperview()
                        }
                    }
                    
                    if convs.isEmpty {
                        // Mostrar mensagem quando não houver conversas
                        let emptyLabel = UILabel()
                        emptyLabel.text = "Nenhuma conversa prioritária no momento"
                        emptyLabel.textAlignment = .center
                        emptyLabel.textColor = .secondaryLabel
                        emptyLabel.tag = 999 // Tag para identificar e remover depois
                        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
                        self.view.addSubview(emptyLabel)
                        
                        NSLayoutConstraint.activate([
                            emptyLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                            emptyLabel.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
                        ])
                    }
                }
            } catch {
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    
                    #if DEBUG
                    print("❌ SupportViewController: Erro ao carregar conversas - \(error)")
                    #endif
                    
                    // Não mostrar alerta se for apenas lista vazia (é normal)
                    // Apenas logar o erro
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet, .networkConnectionLost:
                            print("⚠️ SupportViewController: Sem conexão com a internet")
                        case .timedOut:
                            print("⚠️ SupportViewController: Timeout na requisição")
                        default:
                            print("⚠️ SupportViewController: Erro de conexão - \(urlError.localizedDescription)")
                        }
                    } else {
                        print("⚠️ SupportViewController: Erro - \(error.localizedDescription)")
                    }
                    
                    // Não mostrar alerta para não incomodar o usuário
                    // Apenas manter lista vazia
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        // Verificar se já há um alerta sendo apresentado
        guard presentedViewController == nil else {
            #if DEBUG
            print("⚠️ SupportViewController: Já há um alerta sendo apresentado, ignorando novo alerta")
            #endif
            return
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension SupportViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConversationCell", for: indexPath)
        let conversation = conversations[indexPath.row]
        
        cell.textLabel?.text = conversation.phoneFormatted
        cell.detailTextLabel?.text = "Tempo de espera: \(conversation.waitTime) min"
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conversation = conversations[indexPath.row]
        
        #if DEBUG
        print("💬 SupportViewController: Abrindo chat para \(conversation.phoneFormatted)")
        #endif
        
        // Abrir chat dentro do app (bot responde via Meta Cloud API)
        let chatVC = ChatViewController(conversation: conversation)
        
        if let navController = navigationController {
            #if DEBUG
            print("💬 SupportViewController: NavigationController encontrado, navegando...")
            #endif
            navController.pushViewController(chatVC, animated: true)
        } else {
            #if DEBUG
            print("❌ SupportViewController: NavigationController é nil!")
            #endif
            // Fallback: apresentar modalmente
            let navVC = UINavigationController(rootViewController: chatVC)
            chatVC.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissChat))
            present(navVC, animated: true)
        }
    }
    
    @objc private func dismissChat() {
        dismiss(animated: true)
    }
}
