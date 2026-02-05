import UIKit

class LoginViewController: UIViewController {
    private var usernameTextField: UITextField!
    private var passwordTextField: UITextField!
    private var loginButton: UIButton!
    private var progressIndicator: UIActivityIndicatorView!
    
    private let apiService = ApiService()
    private let authService = AuthService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("📱 LoginViewController: viewDidLoad chamado")
        
        setupUI()
        
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
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Title Label
        let titleLabel = UILabel()
        titleLabel.text = "Pedidos Express"
        titleLabel.font = .boldSystemFont(ofSize: 36)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Username TextField
        usernameTextField = UITextField()
        usernameTextField.placeholder = "Usuário"
        usernameTextField.borderStyle = .roundedRect
        usernameTextField.autocapitalizationType = .none
        usernameTextField.autocorrectionType = .no
        usernameTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(usernameTextField)
        
        // Password TextField
        passwordTextField = UITextField()
        passwordTextField.placeholder = "Senha"
        passwordTextField.borderStyle = .roundedRect
        passwordTextField.isSecureTextEntry = true
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(passwordTextField)
        
        // Login Button
        loginButton = UIButton(type: .system)
        loginButton.setTitle("Entrar", for: .normal)
        loginButton.configuration = UIButton.Configuration.filled()
        loginButton.layer.cornerRadius = 8
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loginButton)
        
        // Progress Indicator
        progressIndicator = UIActivityIndicatorView(style: .medium)
        progressIndicator.hidesWhenStopped = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressIndicator)
        
        // Constraints
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40),
            titleLabel.bottomAnchor.constraint(equalTo: usernameTextField.topAnchor, constant: -56),
            
            usernameTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            usernameTextField.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            usernameTextField.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40),
            usernameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 300),
            usernameTextField.heightAnchor.constraint(equalToConstant: 44),
            
            passwordTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            passwordTextField.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            passwordTextField.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40),
            passwordTextField.topAnchor.constraint(equalTo: usernameTextField.bottomAnchor, constant: 20),
            passwordTextField.heightAnchor.constraint(equalToConstant: 44),
            
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            loginButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40),
            loginButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 20),
            loginButton.heightAnchor.constraint(equalToConstant: 44),
            
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 20)
        ])
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
                authService.saveUser(user, username: username, password: password)
                
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
                    showAlert(title: "Erro", message: error.localizedDescription)
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
