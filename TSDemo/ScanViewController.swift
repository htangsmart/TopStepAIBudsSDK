//
//  ScanViewController.swift
//  TSDemo
//
//  设备扫描页面 - Device Scan View Controller
//  扫描并选择设备，过滤重复设备和无名称设备
//  Scan and select devices, filter duplicate devices and devices without names
//

import UIKit
import CoreBluetooth
import TopStepABMateSDK

/// 设备扫描视图控制器
/// Device scan view controller
final class ScanViewController: UIViewController {

    // MARK: - Properties
    /// 表格视图 - Table view
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    /// 设备列表（已过滤） - Device list (filtered)
    private var devices: [TSDeviceBaseInfo] = []
    
    /// 外设字典 - Peripheral dictionary
    private var peripheralByUUID: [String: CBPeripheral] = [:]
    
    /// 已扫描到的所有设备（用于去重） - All scanned devices (for deduplication)
    private var allScannedDevices: Set<String> = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "选择设备"
        view.backgroundColor = .systemBackground

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "停止扫描", style: .plain, target: self, action: #selector(stopScan))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScan()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        TopStepAIBuds.stopScan()
    }

    @objc private func stopScan() {
        TopStepAIBuds.stopScan()
    }

    // MARK: - Scanning
    /// 开始扫描设备 - Start scanning devices
    private func startScan() {
        devices.removeAll()
        peripheralByUUID.removeAll()
        allScannedDevices.removeAll()
        tableView.reloadData()

        print("🔍 开始扫描设备 - Start scanning devices")
        
        TopStepAIBuds.scanDevice { [weak self] error, deviceInfo, peripheral in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.showError(error)
                }
                return
            }
            
            guard let info = deviceInfo else { return }
            
            // 过滤无名称的设备 - Filter devices without names
            if info.name.isEmpty {
                print("⚠️ 跳过无名称设备 - Skip device without name: \(info.uuid)")
                return
            }
            
            // 过滤重复设备（通过UUID判断） - Filter duplicate devices (by UUID)
            if self.allScannedDevices.contains(info.uuid) {
                // 如果已存在，更新设备信息 - If exists, update device info
                if let index = self.devices.firstIndex(where: { $0.uuid == info.uuid }) {
                    self.devices[index] = info
                }
            } else {
                // 新设备，添加到列表 - New device, add to list
                self.allScannedDevices.insert(info.uuid)
                self.devices.append(info)
            }
            
            // 保存外设对象 - Save peripheral object
            if let p = peripheral {
                self.peripheralByUUID[info.uuid] = p
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Error Handling
    /// 显示错误信息 - Show error message
    private func showError(_ error: NSError) {
        let alert = UIAlertController(
            title: "扫描错误",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension ScanViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let info = devices[indexPath.row]
        
        // 显示设备名称和MAC地址 - Display device name and MAC address
        var content = UIListContentConfiguration.subtitleCell()
        content.text = info.name.isEmpty ? "未知设备" : info.name
        content.secondaryText = "MAC: \(info.mac)"
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let info = devices[indexPath.row]
        
        // 显示确认弹窗 - Show confirmation alert
        let alert = UIAlertController(
            title: "确认连接",
            message: "设备名称: \(info.name)\nMAC地址: \(info.mac)\n\n确定要连接此设备吗？",
            preferredStyle: .alert
        )
        
        // 取消按钮 - Cancel button
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // 确认按钮 - Confirm button
        alert.addAction(UIAlertAction(title: "确认连接", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            // 停止扫描 - Stop scanning
            TopStepAIBuds.stopScan()
            
            // 跳转到设备连接页面 - Navigate to device connection page
            let connectionVC = DeviceConnectionViewController(deviceInfo: info, isAutoReconnect: false)
            self.navigationController?.pushViewController(connectionVC, animated: true)
        })
        
        present(alert, animated: true)
    }
}


