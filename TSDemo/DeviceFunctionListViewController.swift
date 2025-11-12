//
//  DeviceFunctionListViewController.swift
//  TSDemo
//
//  设备功能列表页面 - Device Function List View Controller
//  展示功能列表并跳转到相应的占位页面
//

import UIKit
import TopStepABMateSDK

/// 设备功能列表视图控制器
/// Device function list view controller
final class DeviceFunctionListViewController: UIViewController {
    
    // MARK: - Types
    private struct FunctionItem {
        let title: String
        let subtitle: String
        let action: () -> Void
    }
    
    // MARK: - Properties
    /// 已连接的设备对象 - Connected device object
    private let device: TSSBEarbuds
    
    /// 设备监听器 - Device observer
    private let observer: DeviceObserver
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var items: [FunctionItem] = []
    
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
        buildItems()
        print("📱 功能列表页面 - Function List Page | device: \(device)")
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "功能列表"
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FunctionCell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func buildItems() {
        items = [
            FunctionItem(title: "设备指令发送", subtitle: "发送控制指令至设备 | Device Command") { [weak self] in
                guard let self = self else { return }
                let vc = DeviceCommandViewController(device: self.device, observer: self.observer)
                self.navigationController?.pushViewController(vc, animated: true)
            },
            FunctionItem(title: "数据导入", subtitle: "导入历史数据 | Data Import") { [weak self] in
                guard let self = self else { return }
                let vc = DeviceDataImportViewController(device: self.device, observer: self.observer)
                self.navigationController?.pushViewController(vc, animated: true)
            },
            FunctionItem(title: "音频数据获取", subtitle: "SCO链路与设备回调音频") { [weak self] in
                guard let self = self else { return }
                let vc = AudioDataOptionsViewController(device: self.device, observer: self.observer)
                self.navigationController?.pushViewController(vc, animated: true)
            }
        ]
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension DeviceFunctionListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FunctionCell", for: indexPath)
        let item = items[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        content.text = item.title
        content.secondaryText = item.subtitle
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        item.action()
    }
}
