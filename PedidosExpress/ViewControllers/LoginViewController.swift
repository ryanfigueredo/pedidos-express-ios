import UIKit

class LoginViewController: UIViewController {
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var progressIndicator: UIActivityIndicatorView!
    
    private let apiService = ApiService()
    private let authService = AuthService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Se já estiver logado, ir direto para pedidos
        if authService.isLoggedIn() {
            navigateToMain()
            return
        }
        
        setupUI()
    }
    
    private func setupUI() {
        loginButton.layer.cornerRadius = 8
        progressIndicator.isHidden = true
    }
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
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
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let mainVC = storyboard.instantiateViewController(withIdentifier: "MainNavigationViewController") as? MainNavigationViewController {
            let navController = UINavigationController(rootViewController: mainVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
