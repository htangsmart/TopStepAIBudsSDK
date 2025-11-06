//
//  DeviceFunctionListViewController.swift
//  TSDemo
//
//  设备功能列表页面 - Device Function List View Controller
//  展示设备功能列表（暂时空实现）
//  Displays device function list (temporarily empty implementation)
//

import UIKit
import TopStepABMateSDK

/// 设备功能列表视图控制器
/// Device function list view controller
class DeviceFunctionListViewController: UIViewController {
    
    // MARK: - Properties
    /// 已连接的设备对象 - Connected device object
    private let device: TSSBEarbuds
    
    /// 设备监听器 - Device observer
    private let observer: DeviceObserver
    
    // MARK: - UI Components
    /// 提示标签 - Hint label
    private let hintLabel: UILabel = {
        let label = UILabel()
        label.text = "功能列表页面\nFunction List Page\n\n此页面功能待实现\nThis page is to be implemented"
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    /// 初始化方法
    /// Initializer
    /// - Parameters:
    ///   - device: 已连接的设备对象 - Connected device object
    ///   - observer: 设备监听器 - Device observer
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
        
        // 打印设备信息用于调试 - Print device info for debugging
        print("📱 功能列表页面 - Function List Page")
        print("   设备 - Device: \(device)")
        print("   监听器 - Observer: \(observer)")
    }
    
    // MARK: - UI Setup
    /// 设置UI界面 - Setup UI
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "功能列表"
        
        view.addSubview(hintLabel)
        
        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }
}

