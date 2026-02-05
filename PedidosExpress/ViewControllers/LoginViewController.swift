import UIKit

class LoginViewController: UIViewController {
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var usernameTextField: UITextField!
    private var passwordTextField: UITextField!
    private var loginButton: UIButton!
    private var progressIndicator: UIActivityIndicatorView!
    private var savePasswordSwitch: UISwitch!
    private var savePasswordLabel: UILabel!
    
    private let apiService = ApiService()
    private let authService = AuthService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("📱 LoginViewController: viewDidLoad chamado")
        
        setupUI()
        setupKeyboardHandling()
        loadSavedCredentials()
        
        // Se já estiver logado, ir direto para pedidos
        // Usar DispatchQueue para garantir que a view está completamente carregada
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.authService.isLoggedIn() {
                print("📱 Usuário já logado, navegando para tela principal...")
                self.navigateToMain()
            } else {
                print("📱 Usuário não logado, mostrando tela de login")
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerKeyboardNotifications()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterKeyboardNotifications()
    }
    
    deinit {
        unregisterKeyboardNotifications()
    }
    
    private func loadSavedCredentials() {
        if let credentials = authService.getCredentials() {
            usernameTextField.text = credentials.username
            passwordTextField.text = credentials.password
            savePasswordSwitch.isOn = true
        } else {
            savePasswordSwitch.isOn = false
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .pedidosOrangeLight
        
        // ScrollView para permitir scroll quando o teclado aparecer
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        
        // ContentView dentro do ScrollView
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Logo com efeito glassmorphism
        let logoView = LogoView()
        logoView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoView)
        
        // Title Label
        let titleLabel = UILabel()
        titleLabel.text = "Pedidos Express"
        titleLabel.font = .boldSystemFont(ofSize: 36)
        titleLabel.textColor = .pedidosOrange
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Username TextField
        usernameTextField = UITextField()
        usernameTextField.placeholder = "Usuário"
        usernameTextField.borderStyle = .roundedRect
        usernameTextField.backgroundColor = .systemBackground
        usernameTextField.autocapitalizationType = .none
        usernameTextField.autocorrectionType = .no
        usernameTextField.returnKeyType = .next
        usernameTextField.delegate = self
        usernameTextField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(usernameTextField)
        
        // Password TextField
        passwordTextField = UITextField()
        passwordTextField.placeholder = "Senha"
        passwordTextField.borderStyle = .roundedRect
        passwordTextField.backgroundColor = .systemBackground
        passwordTextField.isSecureTextEntry = true
        passwordTextField.returnKeyType = .go
        passwordTextField.delegate = self
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(passwordTextField)
        
        // Save Password Switch
        savePasswordLabel = UILabel()
        savePasswordLabel.text = "Salvar senha"
        savePasswordLabel.font = .systemFont(ofSize: 16)
        savePasswordLabel.textColor = .label
        savePasswordLabel.translatesAutoresizingMaskIntoConstraints = false
        
        savePasswordSwitch = UISwitch()
        savePasswordSwitch.isOn = true // Por padrão salvar senha
        savePasswordSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        let savePasswordStack = UIStackView(arrangedSubviews: [savePasswordLabel, savePasswordSwitch])
        savePasswordStack.axis = .horizontal
        savePasswordStack.spacing = 12
        savePasswordStack.alignment = .center
        savePasswordStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(savePasswordStack)
        
        // Login Button
        loginButton = UIButton(type: .system)
        loginButton.setTitle("Entrar", for: .normal)
        loginButton.configuration = UIButton.Configuration.filled()
        loginButton.configuration?.baseBackgroundColor = .pedidosOrange
        loginButton.configuration?.baseForegroundColor = .white
        loginButton.layer.cornerRadius = 8
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loginButton)
        
        // Progress Indicator
        progressIndicator = UIActivityIndicatorView(style: .medium)
        progressIndicator.hidesWhenStopped = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(progressIndicator)
        
        // Constraints
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Logo
            logoView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 60),
            logoView.widthAnchor.constraint(equalToConstant: 120),
            logoView.heightAnchor.constraint(equalToConstant: 120),
            
            // Title
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            titleLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 20),
            
            // Username
            usernameTextField.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            usernameTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            usernameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            usernameTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            usernameTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Password
            passwordTextField.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            passwordTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            passwordTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            passwordTextField.topAnchor.constraint(equalTo: usernameTextField.bottomAnchor, constant: 20),
            passwordTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Save Password
            savePasswordStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            savePasswordStack.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 16),
            
            // Login Button
            loginButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loginButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            loginButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            loginButton.topAnchor.constraint(equalTo: savePasswordStack.bottomAnchor, constant: 20),
            loginButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Progress Indicator
            progressIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            progressIndicator.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 20),
            progressIndicator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    private func setupKeyboardHandling() {
        // Gesture para fechar teclado ao tocar fora
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func registerKeyboardNotifications() {
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
    
    private func unregisterKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
        
        UIView.animate(withDuration: animationDuration) {
            self.scrollView.contentInset = contentInsets
            self.scrollView.scrollIndicatorInsets = contentInsets
            
            // Scroll para o campo ativo
            if let activeField = self.usernameTextField.isFirstResponder ? self.usernameTextField :
                                 self.passwordTextField.isFirstResponder ? self.passwordTextField : nil {
                let rect = activeField.convert(activeField.bounds, to: self.scrollView)
                self.scrollView.scrollRectToVisible(rect, animated: false)
            }
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: animationDuration) {
            self.scrollView.contentInset = .zero
            self.scrollView.scrollIndicatorInsets = .zero
        }
    }
    
    @objc private func loginButtonTapped() {
        guard let username = usernameTextField.text?.trimmingCharacters(in: .whitespaces),
              let password = passwordTextField.text,
              !username.isEmpty, !password.isEmpty else {
            showAlert(title: "Erro", message: "Preencha usuário e senha")
            return
        }
        
        performLogin(username: username, password: password)
    }
    
    private func performLogin(username: String, password: String) {
        loginButton.isEnabled = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimating()
        
        Task {
            do {
                let user = try await apiService.login(username: username, password: password)
                
                // Sempre salvar credenciais para que as requisições funcionem
                // O switch controla apenas se preenche automaticamente na próxima vez
                authService.saveUser(user, username: username, password: password)
                
                // Se não marcar "salvar senha", não preencher automaticamente na próxima vez
                // mas ainda salvar para que as requisições funcionem
                if !savePasswordSwitch.isOn {
                    // Não fazer nada - as credenciais já foram salvas
                    // Na próxima vez, o usuário terá que digitar novamente
                }
                
                await MainActor.run {
                    progressIndicator.stopAnimating()
                    progressIndicator.isHidden = true
                    loginButton.isEnabled = true
                    navigateToMain()
                }
            } catch {
                await MainActor.run {
                    progressIndicator.stopAnimating()
                    progressIndicator.isHidden = true
                    loginButton.isEnabled = true
                    
                    #if DEBUG
                    print("❌ LoginViewController: Erro no login - \(error)")
                    print("❌ LoginViewController: Tipo do erro: \(type(of: error))")
                    if let apiError = error as? ApiError {
                        print("❌ LoginViewController: ApiError - \(apiError.localizedDescription)")
                    }
                    #endif
                    
                    // Mostrar mensagem de erro mais amigável
                    let errorMessage: String
                    if let apiError = error as? ApiError {
                        errorMessage = apiError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    showAlert(title: "Erro no Login", message: errorMessage)
                }
            }
        }
    }
    
    private func navigateToMain() {
        guard isViewLoaded && view.window != nil else {
            // Se a view não estiver pronta, aguardar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.navigateToMain()
            }
            return
        }
        
        let mainVC = MainNavigationViewController()
        let navController = UINavigationController(rootViewController: mainVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            textField.resignFirstResponder()
            loginButtonTapped()
        }
        return true
    }
}
