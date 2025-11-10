//
//  DeviceCommandViewController.swift
//  TSDemo
//
//  设备指令页面 - Device Command Page
//  展示设备指令分类列表
//

import UIKit
import TopStepABMateSDK
import RxSwift

/// 设备指令发送页面
/// Device command sending page
final class DeviceCommandViewController: UIViewController {
    
    // MARK: - Properties
    private let device: TSSBEarbuds
    private let observer: DeviceObserver
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var categories: [CommandCategory] = []
    private let disposeBag = DisposeBag()
    
    // MARK: - Initialization
    init(device: TSSBEarbuds, observer: DeviceObserver) {
        self.device = device
        self.observer = observer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCategories()
        setupBindings()
        print("📦 DeviceCommandViewController init with device: \(device)")
        print("Observer: \(observer)")
    }
    
    // MARK: - Bindings
    private func setupBindings() {
        // 监听支持功能变化，更新分类列表显示
        observer.supportFunction
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.tableView.reloadData()
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "设备指令"
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CategoryCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadCategories() {
        categories = CommandHelper.getAllCategories()
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension DeviceCommandViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        let category = categories[indexPath.row]
        let supportFunction = observer.supportFunction.value
        let supportedCommands = category.getSupportedCommands(supportFunction: supportFunction)
        
        var content = UIListContentConfiguration.subtitleCell()
        content.text = category.name
        if supportedCommands.count < category.commands.count {
            content.secondaryText = "\(supportedCommands.count)/\(category.commands.count) 个指令"
        } else {
            content.secondaryText = "\(category.commands.count) 个指令"
        }
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let category = categories[indexPath.row]
        let commandListVC = CommandListViewController(device: device, observer: observer, category: category)
        navigationController?.pushViewController(commandListVC, animated: true)
    }
}
