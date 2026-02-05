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
                
                await MainActor.run {
                    self.conversations = convs
                    self.conversationsTableView.reloadData()
                    self.progressIndicator.stopAnimating()
                    
                    if convs.isEmpty {
                        // Mostrar mensagem quando não houver conversas
                        let emptyLabel = UILabel()
                        emptyLabel.text = "Nenhuma conversa prioritária no momento"
                        emptyLabel.textAlignment = .center
                        emptyLabel.textColor = .secondaryLabel
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
                    
                    // Mensagem mais clara sobre erro de conexão
                    var errorMessage = "Erro ao carregar conversas."
                    
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet, .networkConnectionLost:
                            errorMessage = "Sem conexão com a internet. Verifique sua conexão e tente novamente."
                        case .timedOut:
                            errorMessage = "Tempo de conexão esgotado. Tente novamente."
                        default:
                            errorMessage = "Erro de conexão: \(urlError.localizedDescription)"
                        }
                    } else if error is DecodingError {
                        errorMessage = "Erro ao processar dados. Verifique sua conexão."
                    } else {
                        errorMessage = "Erro: \(error.localizedDescription)"
                    }
                    
                    self.showAlert(title: "Erro de Conexão", message: errorMessage)
                }
            }
        }
    }
    
    private func openWhatsApp(_ conversation: PriorityConversation) {
        if let url = URL(string: conversation.whatsappUrl) {
            UIApplication.shared.open(url)
        }
    }
    
    private func showAlert(title: String, message: String) {
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
        openWhatsApp(conversation)
    }
}
