import UIKit

class MenuViewController: UIViewController {
    private var menuTableView: UITableView!
    private var progressIndicator: UIActivityIndicatorView!
    
    private let apiService = ApiService()
    private var menuItems: [MenuItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cardápio"
        
        setupUI()
        setupTableView()
        loadMenu()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addMenuItem)
        )
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        menuTableView = UITableView()
        menuTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuTableView)
        
        progressIndicator = UIActivityIndicatorView(style: .large)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.hidesWhenStopped = true
        view.addSubview(progressIndicator)
        
        NSLayoutConstraint.activate([
            menuTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            menuTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            menuTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            menuTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadMenu()
    }
    
    private func setupTableView() {
        menuTableView.delegate = self
        menuTableView.dataSource = self
        menuTableView.register(MenuItemTableViewCell.self, forCellReuseIdentifier: "MenuItemCell")
    }
    
    private func loadMenu() {
        progressIndicator.startAnimating()
        
        Task {
            do {
                let items = try await apiService.getMenu()
                
                await MainActor.run {
                    self.menuItems = items
                    self.menuTableView.reloadData()
                    self.progressIndicator.stopAnimating()
                }
            } catch {
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    self.showAlert(title: "Erro", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func addMenuItem() {
        let alert = UIAlertController(title: "Novo Item", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Nome"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Preço"
            textField.keyboardType = .decimalPad
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Categoria"
        }
        
        alert.addAction(UIAlertAction(title: "Adicionar", style: .default) { [weak self] _ in
            guard let nameField = alert.textFields?[0],
                  let priceField = alert.textFields?[1],
                  let categoryField = alert.textFields?[2],
                  let name = nameField.text, !name.isEmpty,
                  let priceText = priceField.text,
                  let price = Double(priceText),
                  let category = categoryField.text, !category.isEmpty else {
                return
            }
            
            self?.createMenuItem(id: UUID().uuidString, name: name, price: price, category: category)
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func createMenuItem(id: String, name: String, price: Double, category: String) {
        progressIndicator.startAnimating()
        
        Task {
            do {
                _ = try await apiService.createMenuItem(id: id, name: name, price: price, category: category)
                
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    self.loadMenu()
                }
            } catch {
                await MainActor.run {
                    self.progressIndicator.stopAnimating()
                    self.showAlert(title: "Erro", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension MenuViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MenuItemCell", for: indexPath) as! MenuItemTableViewCell
        cell.configure(with: menuItems[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = menuItems[indexPath.row]
        
        let toggleAction = UIContextualAction(
            style: .normal,
            title: item.available ? "Desativar" : "Ativar"
        ) { [weak self] _, _, completion in
            self?.toggleItemAvailability(item)
            completion(true)
        }
        toggleAction.backgroundColor = item.available ? .systemOrange : .systemGreen
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Deletar") { [weak self] _, _, completion in
            self?.deleteMenuItem(item)
            completion(true)
        }
        
        return UISwipeActionsConfiguration(actions: [deleteAction, toggleAction])
    }
    
    private func toggleItemAvailability(_ item: MenuItem) {
        Task {
            do {
                _ = try await apiService.updateMenuItem(id: item.id, available: !item.available)
                await MainActor.run {
                    self.loadMenu()
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "Erro", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func deleteMenuItem(_ item: MenuItem) {
        let alert = UIAlertController(title: "Confirmar", message: "Deletar \(item.name)?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Deletar", style: .destructive) { [weak self] _ in
            Task {
                do {
                    _ = try await self?.apiService.deleteMenuItem(id: item.id)
                    await MainActor.run {
                        self?.loadMenu()
                    }
                } catch {
                    await MainActor.run {
                        self?.showAlert(title: "Erro", message: error.localizedDescription)
                    }
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        
        present(alert, animated: true)
    }
}
