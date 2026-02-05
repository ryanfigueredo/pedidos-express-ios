import UIKit

class ChatViewController: UIViewController {
    private var conversation: PriorityConversation
    private var messages: [ChatMessage] = []
    private let apiService = ApiService()
    
    private var tableView: UITableView!
    private var inputContainerView: UIView!
    private var messageTextView: UITextView!
    private var messageTextField: UITextField! // TESTE: Usar UITextField temporariamente
    private var sendButton: UIButton!
    private var whatsappButton: UIButton!
    
    private var bottomConstraint: NSLayoutConstraint!
    private var isSending = false
    
    init(conversation: PriorityConversation) {
        self.conversation = conversation
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if DEBUG
        print("💬 ChatViewController: viewDidLoad - \(conversation.phoneFormatted)")
        #endif
        
        setupUI()
        setupKeyboardObservers()
        
        // Carregar histórico de mensagens
        loadConversationHistory()
    }
    
    private func loadConversationHistory() {
        Task {
            do {
                // Remover número formatado e usar apenas números
                let phone = conversation.phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                
                #if DEBUG
                print("💬 ChatViewController: Carregando histórico para \(phone)")
                #endif
                
                let history = try await apiService.getConversationHistory(phone: phone)
                
                await MainActor.run {
                    if history.isEmpty {
                        // Se não houver histórico, adicionar mensagem inicial
                        self.messages.append(ChatMessage(
                            id: UUID().uuidString,
                            text: "Cliente pediu atendimento humano pelo bot.",
                            isAttendant: false,
                            timestamp: Date(),
                            status: .sent
                        ))
                    } else {
                        // Ordenar mensagens por timestamp (mais antigas primeiro)
                        self.messages = history.sorted { $0.timestamp < $1.timestamp }
                    }
                    
                    self.tableView.reloadData()
                    self.scrollToBottom()
                    
                    #if DEBUG
                    print("💬 ChatViewController: Histórico carregado - \(self.messages.count) mensagens")
                    #endif
                }
            } catch {
                await MainActor.run {
                    #if DEBUG
                    print("❌ ChatViewController: Erro ao carregar histórico - \(error)")
                    #endif
                    
                    // Em caso de erro, adicionar mensagem inicial
                    self.messages.append(ChatMessage(
                        id: UUID().uuidString,
                        text: "Cliente pediu atendimento humano pelo bot.",
                        isAttendant: false,
                        timestamp: Date(),
                        status: .sent
                    ))
                    
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Não chamar becomeFirstResponder aqui - pode causar problemas se a view não estiver pronta
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        #if DEBUG
        print("💬 ChatViewController: viewDidAppear")
        print("💬 ChatViewController: messageTextView existe: \(messageTextView != nil)")
        print("💬 ChatViewController: messageTextField existe: \(messageTextField != nil)")
        #endif
        
        // Abrir teclado após a view aparecer completamente
        // TESTE: Usar TextField temporariamente
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            #if DEBUG
            print("💬 ChatViewController: Tentando abrir teclado no TextField...")
            print("💬 ChatViewController: TextField.window: \(self.messageTextField.window != nil ? "existe" : "nil")")
            print("💬 ChatViewController: TextField.superview: \(self.messageTextField.superview != nil ? "existe" : "nil")")
            print("💬 ChatViewController: TextField.canBecomeFirstResponder: \(self.messageTextField.canBecomeFirstResponder)")
            print("💬 ChatViewController: TextField.isEnabled: \(self.messageTextField.isEnabled)")
            print("💬 ChatViewController: TextField.isUserInteractionEnabled: \(self.messageTextField.isUserInteractionEnabled)")
            print("💬 ChatViewController: TextField.isHidden: \(self.messageTextField.isHidden)")
            #endif
            
            guard self.messageTextField.window != nil else {
                #if DEBUG
                print("⚠️ ChatViewController: TextField ainda não está na hierarquia de views, tentando novamente...")
                #endif
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.messageTextField.canBecomeFirstResponder {
                        let success = self.messageTextField.becomeFirstResponder()
                        #if DEBUG
                        print("💬 ChatViewController: TextField.becomeFirstResponder (tentativa 2) retornou: \(success)")
                        print("💬 ChatViewController: TextField.isFirstResponder: \(self.messageTextField.isFirstResponder)")
                        #endif
                    }
                }
                return
            }
            
            if self.messageTextField.canBecomeFirstResponder {
                let success = self.messageTextField.becomeFirstResponder()
                #if DEBUG
                print("💬 ChatViewController: TextField.becomeFirstResponder retornou: \(success)")
                print("💬 ChatViewController: TextField.isFirstResponder: \(self.messageTextField.isFirstResponder)")
                if success {
                    print("✅ ChatViewController: Teclado DEVE estar visível agora!")
                    print("💡 Se o teclado não aparecer, pode ser problema do simulador")
                }
                #endif
            } else {
                #if DEBUG
                print("❌ ChatViewController: TextField NÃO pode se tornar first responder!")
                #endif
            }
        }
    }
    
    private func setupUI() {
        #if DEBUG
        print("💬 ChatViewController: setupUI iniciado")
        #endif
        
        view.backgroundColor = .pedidosOrangeLight
        
        title = conversation.phoneFormatted
        
        #if DEBUG
        print("💬 ChatViewController: Título definido: \(conversation.phoneFormatted)")
        #endif
        
        // Botão para abrir WhatsApp externo
        whatsappButton = UIButton(type: .system)
        whatsappButton.setImage(UIImage(systemName: "message.fill"), for: .normal)
        whatsappButton.tintColor = .pedidosOrange
        whatsappButton.addTarget(self, action: #selector(openWhatsApp), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: whatsappButton)
        
        // TableView para mensagens
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .pedidosOrangeLight
        tableView.register(ChatMessageCell.self, forCellReuseIdentifier: "ChatMessageCell")
        view.addSubview(tableView)
        
        // Container para input
        inputContainerView = UIView()
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.backgroundColor = .systemBackground
        inputContainerView.layer.shadowColor = UIColor.black.cgColor
        inputContainerView.layer.shadowOffset = CGSize(width: 0, height: -2)
        inputContainerView.layer.shadowRadius = 4
        inputContainerView.layer.shadowOpacity = 0.1
        inputContainerView.isUserInteractionEnabled = true
        
        // Adicionar gesto de toque no container para focar o campo de texto
        // Mas permitir que toques no campo de texto passem direto para ele
        // REMOVIDO: Gesto pode estar bloqueando entrada de texto
        // Se precisar focar o campo, usar toque direto no campo
        
        view.addSubview(inputContainerView)
        
        #if DEBUG
        print("💬 ChatViewController: inputContainerView criado e adicionado")
        #endif
        
        // Stack para input e botão
        let inputStack = UIStackView()
        inputStack.axis = .horizontal
        inputStack.spacing = 8
        inputStack.alignment = .center
        inputStack.translatesAutoresizingMaskIntoConstraints = false
        inputStack.isUserInteractionEnabled = true
        
        // TESTE: Usar UITextField com configuração mínima para garantir que funcione
        messageTextField = UITextField()
        messageTextField.translatesAutoresizingMaskIntoConstraints = false
        messageTextField.backgroundColor = .pedidosOrangeLight
        messageTextField.layer.cornerRadius = 20
        messageTextField.font = .systemFont(ofSize: 16)
        messageTextField.placeholder = "Digite sua mensagem..."
        
        // Padding usando textContainerInset equivalente
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 44))
        messageTextField.leftView = paddingView
        messageTextField.leftViewMode = .always
        let paddingViewRight = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 44))
        messageTextField.rightView = paddingViewRight
        messageTextField.rightViewMode = .always
        
        // Configurações CRÍTICAS para garantir que funcione
        messageTextField.delegate = self
        messageTextField.keyboardType = .default
        messageTextField.autocorrectionType = .default
        messageTextField.autocapitalizationType = .sentences
        messageTextField.returnKeyType = .send
        messageTextField.borderStyle = .none // IMPORTANTE: sem borderStyle pode causar problemas
        messageTextField.isUserInteractionEnabled = true
        messageTextField.isEnabled = true
        messageTextField.isHidden = false
        messageTextField.alpha = 1.0
        
        // Adicionar target para mudanças de texto
        messageTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        #if DEBUG
        print("💬 ChatViewController: TextField configurado:")
        print("   isEnabled: \(messageTextField.isEnabled)")
        print("   isUserInteractionEnabled: \(messageTextField.isUserInteractionEnabled)")
        print("   isHidden: \(messageTextField.isHidden)")
        print("   alpha: \(messageTextField.alpha)")
        print("   canBecomeFirstResponder: \(messageTextField.canBecomeFirstResponder)")
        #endif
        
        // Manter UITextView para compatibilidade, mas usar TextField por enquanto
        messageTextView = UITextView()
        messageTextView.isHidden = true // Esconder UITextView temporariamente
        messageTextView.isUserInteractionEnabled = false
        
        #if DEBUG
        print("💬 ChatViewController: Campo de texto (UITextView) configurado - enabled: \(messageTextView.isEditable), userInteraction: \(messageTextView.isUserInteractionEnabled)")
        #endif
        
        sendButton = UIButton(type: .system)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.tintColor = .pedidosOrange
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        sendButton.isEnabled = false
        
        // Adicionar TextField ao stack view
        inputStack.addArrangedSubview(messageTextField)
        inputStack.addArrangedSubview(messageTextView) // Manter TextView escondido para compatibilidade
        inputStack.addArrangedSubview(sendButton)
        inputContainerView.addSubview(inputStack)
        
        // Garantir que o stack view não bloqueie interações
        inputStack.isUserInteractionEnabled = true
        
        #if DEBUG
        print("💬 ChatViewController: Stack view e campo de texto adicionados")
        print("💬 ChatViewController: messageTextView.superview = \(messageTextView.superview?.description ?? "nil")")
        #endif
        
        bottomConstraint = inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor),
            
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
            
            inputStack.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: 8),
            inputStack.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            inputStack.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            inputStack.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -8),
            
            messageTextField.heightAnchor.constraint(equalToConstant: 44),
            messageTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            messageTextView.heightAnchor.constraint(lessThanOrEqualToConstant: 120),
            sendButton.widthAnchor.constraint(equalToConstant: 44),
            sendButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Observar mudanças no texto via NotificationCenter (UITextView não tem addTarget)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textViewTextDidChange),
            name: UITextView.textDidChangeNotification,
            object: messageTextView
        )
        
        #if DEBUG
        print("💬 ChatViewController: setupUI concluído")
        print("💬 ChatViewController: messageTextView frame será definido após layout")
        #endif
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        #if DEBUG
        if let textView = messageTextView {
            print("💬 ChatViewController: messageTextView frame = \(textView.frame)")
            print("💬 ChatViewController: messageTextView isUserInteractionEnabled = \(textView.isUserInteractionEnabled)")
            print("💬 ChatViewController: messageTextView isEditable = \(textView.isEditable)")
            print("💬 ChatViewController: messageTextView isFirstResponder = \(textView.isFirstResponder)")
            print("💬 ChatViewController: inputContainerView frame = \(inputContainerView.frame)")
            print("💬 ChatViewController: inputContainerView isUserInteractionEnabled = \(inputContainerView.isUserInteractionEnabled)")
        }
        #endif
    }
    
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        bottomConstraint.constant = -keyboardHeight + view.safeAreaInsets.bottom
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        bottomConstraint.constant = 0
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func focusMessageField() {
        #if DEBUG
        print("💬 ChatViewController: Container tocado, focando campo de texto (TextField)")
        #endif
        if !messageTextField.isFirstResponder {
            messageTextField.becomeFirstResponder()
        }
    }
    
    @objc private func textFieldDidChange() {
        // TESTE: Método para TextField
        let text = messageTextField.text ?? ""
        
        #if DEBUG
        print("💬 ChatViewController: textFieldDidChange - texto atual: '\(text)'")
        #endif
        
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.isEnabled = hasText && !isSending
        sendButton.alpha = hasText && !isSending ? 1.0 : 0.5
        
        #if DEBUG
        print("💬 ChatViewController: Botão enviar habilitado: \(sendButton.isEnabled)")
        #endif
    }
    
    @objc private func textViewTextDidChange() {
        let text = messageTextView.text ?? ""
        
        // Placeholder removido temporariamente para teste
        
        #if DEBUG
        print("💬 ChatViewController: textViewTextDidChange - texto atual: '\(text)'")
        #endif
        
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.isEnabled = hasText && !isSending
        sendButton.alpha = hasText && !isSending ? 1.0 : 0.5
        
        #if DEBUG
        print("💬 ChatViewController: Botão enviar habilitado: \(sendButton.isEnabled)")
        #endif

        // Ajustar altura do textView conforme o conteúdo
        let size = messageTextView.sizeThatFits(CGSize(width: messageTextView.frame.width, height: .greatestFiniteMagnitude))
        let newHeight = min(max(size.height, 44), 120)
        messageTextView.constraints.forEach { constraint in
            if constraint.firstAttribute == .height && constraint.constant != newHeight {
                constraint.constant = newHeight
            }
        }
    }
    
    @objc private func sendMessage() {
        // TESTE: Usar TextField temporariamente
        let text = (messageTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else {
            return
        }
        
        // TESTE: Limpar TextField
        messageTextField.text = ""
        sendButton.isEnabled = false
        sendButton.alpha = 0.5
        isSending = true
        
        let tempId = UUID().uuidString
        let newMessage = ChatMessage(
            id: tempId,
            text: text,
            isAttendant: true,
            timestamp: Date(),
            status: .sending
        )
        
        messages.append(newMessage)
        tableView.reloadData()
        scrollToBottom()
        
        Task {
            do {
                // Formatar telefone para envio
                var phone = conversation.phone.replacingOccurrences(of: "@s.whatsapp.net", with: "")
                phone = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if !phone.hasPrefix("55") && phone.count >= 10 {
                    phone = "55\(phone)"
                }
                
                let success = try await apiService.sendWhatsAppMessage(phone: phone, message: text)
                
                await MainActor.run {
                    if let index = self.messages.firstIndex(where: { $0.id == tempId }) {
                        self.messages[index] = ChatMessage(
                            id: tempId,
                            text: text,
                            isAttendant: true,
                            timestamp: Date(),
                            status: success ? .sent : .error
                        )
                        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                    }
                    self.isSending = false
                    self.textFieldDidChange()
                }
            } catch {
                await MainActor.run {
                    if let index = self.messages.firstIndex(where: { $0.id == tempId }) {
                        self.messages[index] = ChatMessage(
                            id: tempId,
                            text: text,
                            isAttendant: true,
                            timestamp: Date(),
                            status: .error
                        )
                        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                    }
                    self.isSending = false
                    self.textFieldDidChange()
                    
                    self.showAlert(title: "Erro", message: "Não foi possível enviar a mensagem. Tente novamente.")
                }
            }
        }
    }
    
    @objc private func openWhatsApp() {
        if let url = URL(string: conversation.whatsappUrl) {
            UIApplication.shared.open(url)
        }
    }
    
    private func scrollToBottom() {
        DispatchQueue.main.async {
            let indexPath = IndexPath(row: self.messages.count - 1, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatMessageCell", for: indexPath) as! ChatMessageCell
        cell.configure(with: messages[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - UITextViewDelegate
extension ChatViewController: UITextViewDelegate {
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        #if DEBUG
        print("💬 ChatViewController: textViewShouldBeginEditing chamado")
        #endif
        return true
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        #if DEBUG
        print("💬 ChatViewController: textViewDidBeginEditing - teclado deve estar visível agora")
        print("💬 ChatViewController: Campo de texto está habilitado: \(textView.isEditable)")
        print("💬 ChatViewController: Campo de texto pode receber interação: \(textView.isUserInteractionEnabled)")
        #endif
        
        // Placeholder removido temporariamente para teste
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        #if DEBUG
        let currentText = textView.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: text)
        print("💬 ChatViewController: shouldChangeTextIn chamado!")
        print("   Range: \(range)")
        print("   Texto a inserir: '\(text)' (length: \(text.count))")
        print("   Texto atual: '\(currentText)'")
        print("   Novo texto será: '\(newText)'")
        print("   textView.isEditable: \(textView.isEditable)")
        print("   textView.isUserInteractionEnabled: \(textView.isUserInteractionEnabled)")
        #endif
        
        // Se pressionar Enter, enviar mensagem
        if text == "\n" {
            sendMessage()
            return false
        }
        
        #if DEBUG
        print("💬 ChatViewController: shouldChangeTextIn retornando TRUE - texto deve ser inserido")
        #endif
        
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        textViewTextDidChange()
    }
}

// MARK: - UITextFieldDelegate
extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // TESTE: Enviar quando pressionar Enter no TextField
        sendMessage()
        return false
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        #if DEBUG
        let currentText = textField.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
        print("✅✅✅ ChatViewController: TextField shouldChangeCharactersIn chamado! ✅✅✅")
        print("   Range: \(range)")
        print("   Texto a inserir: '\(string)' (length: \(string.count))")
        print("   Texto atual: '\(currentText)'")
        print("   Novo texto será: '\(newText)'")
        print("   textField.isFirstResponder: \(textField.isFirstResponder)")
        print("   textField.isEnabled: \(textField.isEnabled)")
        print("   textField.isUserInteractionEnabled: \(textField.isUserInteractionEnabled)")
        #endif
        
        // IMPORTANTE: Retornar true para permitir a mudança
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        #if DEBUG
        print("✅ ChatViewController: TextField começou a editar!")
        print("   textField.text: '\(textField.text ?? "")'")
        print("   textField.isFirstResponder: \(textField.isFirstResponder)")
        #endif
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        #if DEBUG
        print("💬 ChatViewController: TextField terminou de editar")
        #endif
    }
}
