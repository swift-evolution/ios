import UIKit

final class SettingsTableViewController: UITableViewController {

    private var dataSource: [Section] = []
    
    private lazy var descriptionView: DescriptionView? = {
        guard
            let view: DescriptionView = DescriptionView.fromNib()
            else {
                return nil
        }
        
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        descriptionView?.delegate = self
        registerNotifications()
        
        title = "Settings"
        tableView.tableHeaderView = descriptionView
        
        tableView.registerNib(withClass: SwitchTableViewCell.self)
        tableView.registerNib(withClass: CustomSubtitleTableViewCell.self)
        
        buildDataSource()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        getDetails(from: User.current)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        removeNotifications()
    }
    private func buildDataSource() {
        var footerDescription: String?
        
        if User.current == nil {
            footerDescription = "To enable notifications, you need to configure your iCloud account on iOS"
        }
        else if let appDelegate = UIApplication.shared.delegate as? AppDelegate, appDelegate.authorizedNotification == false {
            footerDescription = "You need to authorize Push Notifications. Switch on and you will be asked."
        }
        
        let notifications = Section(section: .notifications,
                                    items: [
                                        Subscription(text: "Proposal creation/update", type: .undefined, value: "", subscribed: false)],
                                    footer: footerDescription,
                                    grouped: false)
        
        let about = Section(section: .about,
                            items: [
                                Item(text: "See all details about this app", type: .undefined, value: "")],
                            footer: nil,
                            grouped: false)
        
        
        dataSource = [notifications, about]
    }
}

// MARK: - UITableView DataSource
extension SettingsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()
            
        let section = dataSource[indexPath.section]
        let item = section.items[indexPath.row]
        
        if section.section == .notifications {
            let switchCell = tableView.cell(forRowAt: indexPath) as SwitchTableViewCell
            
            switchCell.descriptionLabel?.text = item.text
            switchCell.indexPath = indexPath
            switchCell.delegate = self

            switchCell.activeSwitch.isEnabled = User.current == nil ? false : true
            
            cell = switchCell
        }
        else if section.section == .about {
            cell = tableView.cell(forRowAt: indexPath) as CustomSubtitleTableViewCell
            cell.textLabel?.text        = "Contributors, licenses and more"
            cell.detailTextLabel?.text  = item.text
        }
        
        return cell
    }
}

// MARK: - UITableView Delegate
extension SettingsTableViewController {
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = dataSource[section]
        
        return section.section.description
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let section = dataSource[section]
        
        return section.footer
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let about = dataSource[indexPath.section]
        
        if about.section == .about {
            performSegue(withIdentifier: "AboutStoryboardSegue", sender: nil)
        }
    }
}

// MARK: - UITableView Delegate
extension SettingsTableViewController: SwitchTableViewCellProtocol {
    func `switch`(active: Bool, didChangeSelectionAt indexPath: IndexPath) {
        // TODO: Register selection
    }
}

// MARK: - Network
extension SettingsTableViewController {
    private func getDetails(from user: User?) {
        guard let user = user else {
            return
        }

        DispatchQueue.main.async {
            self.notification(loading: true)
        }
        
        NotificationsService.getDetails(from: user) { [weak self] result in
            guard let user = result.value else {
                if let error = result.error {
                    print("Error: \(error)")
                }
                return
            }
            
            self?.updateNotification(to: user)
            
            DispatchQueue.main.async {
                self?.notification(loading: false)
            }
        }
    }
    
    private func registerNotifications() {
        // TODO: Update user details request
    }
}

// MARK: - Notification Center
extension SettingsTableViewController {
    private func registerNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didReceiveNotification(_:)),
                                               name: NSNotification.Name.NotificationRegister,
                                               object: nil)
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(NSNotification.Name.NotificationRegister)
    }
    
    @objc
    private func didReceiveNotification(_ notification: Notification) {
        guard notification.name == NSNotification.Name.NotificationRegister else {
            return
        }
        
        getDetails(from: User.current)
    }
}

// MARK: - Mutation
extension SettingsTableViewController {
    private func indexPathForNotifications() -> IndexPath? {
        var indexPath: IndexPath?
        
        for (s, section) in dataSource.enumerated() {
            guard section.section == .notifications else {
                continue
            }
            
            for (i, item) in section.items.enumerated() {
                guard item is Subscription else {
                    continue
                }
                
                indexPath = IndexPath(row: i, section: s)
            }
        }
        
        return indexPath
    }
    
    private func notification(loading: Bool) {
        guard let indexPath = indexPathForNotifications() else {
            return
        }
        
        guard let cell = tableView.cellForRow(at: indexPath) as? SwitchTableViewCell else {
            return
        }
        
        cell.loadingActivity = loading
        
        if let item = dataSource[indexPath.section].items[indexPath.row] as? Subscription {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
                cell.activeSwitch.setOn(item.subscribed, animated: true)
            }
        }
    }
    
    private func updateNotification(to user: User) {
        guard let indexPath = indexPathForNotifications() else {
            return
        }
        
        var source = dataSource
        var section = source[indexPath.section]
        
        if var item = section.items[indexPath.row] as? Subscription, let tags = user.tags {
            item.subscribed = tags.count > 0
            section.items[indexPath.row] = item
        }
        
        source[indexPath.section] = section
        
        dataSource = source
    }
}

// MARK: - DescriptionView Delegate
extension SettingsTableViewController: DescriptionViewProtocol {
    func closeAction() {
        dismiss(animated: true)
    }
}
