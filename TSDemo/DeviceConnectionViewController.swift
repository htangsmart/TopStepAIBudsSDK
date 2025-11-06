//
//  DeviceConnectionViewController.swift
//  TSDemo
//
//  设备连接页面 - Device Connection View Controller
//  用于连接设备并显示连接进度
//  Used for connecting devices and displaying connection progress
//

import UIKit
import TopStepABMateSDK
import CoreBluetooth

/// 设备连接视图控制器
/// Device connection view controller
class DeviceConnectionViewController: UIViewController {
    
    // MARK: - Properties
    /// 要连接的设备信息 - Device info to connect
    private let deviceInfo: TSDeviceBaseInfo
    
    /// 是否为自动重连模式 - Whether it's auto-reconnect mode
    private let isAutoReconnect: Bool
    
    /// 设备监听器 - Device observer
    private var observer: DeviceObserver?
    
    /// 是否正在连接 - Whether connecting
    private var isConnecting = false
    
    // MARK: - UI Components
    /// 设备名称标签 - Device name label
    private let deviceNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// 设备MAC地址标签 - Device MAC address label
    private let deviceMacLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// 连接状态标签 - Connection state label
    private let connectionStateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// 进度指示器 - Progress indicator
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    /// 错误信息标签 - Error message label
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.textColor = .systemRed
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// 重新连接按钮 - Reconnect button
    private let reconnectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("重新连接", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Initialization
    /// 初始化方法
    /// Initializer
    /// - Parameters:
    ///   - deviceInfo: 设备信息 - Device information
    ///   - isAutoReconnect: 是否为自动重连 - Whether it's auto-reconnect
    init(deviceInfo: TSDeviceBaseInfo, isAutoReconnect: Bool = false) {
        self.deviceInfo = deviceInfo
        self.isAutoReconnect = isAutoReconnect
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        
        // 如果是自动重连模式，隐藏返回按钮 - Hide back button in auto-reconnect mode
        if isAutoReconnect {
            navigationItem.hidesBackButton = true
        }
        
        // 自动开始连接 - Auto start connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startConnection()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 如果正在连接，停止连接 - Stop connection if connecting
        if isConnecting {
            // 注意：SDK 可能没有提供停止连接的方法，这里只是标记状态
            // Note: SDK may not provide a method to stop connection, just mark the state here
            isConnecting = false
        }
    }
    
    // MARK: - UI Setup
    /// 设置UI界面 - Setup UI
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = isAutoReconnect ? "自动重连" : "连接设备"
        
        // 设置设备信息 - Set device information
        deviceNameLabel.text = deviceInfo.name.isEmpty ? "未知设备" : deviceInfo.name
        deviceMacLabel.text = "MAC: \(deviceInfo.mac)"
        connectionStateLabel.text = "准备连接..."
        connectionStateLabel.textColor = .systemBlue
        
        // 添加子视图 - Add subviews
        view.addSubview(deviceNameLabel)
        view.addSubview(deviceMacLabel)
        view.addSubview(connectionStateLabel)
        view.addSubview(activityIndicator)
        view.addSubview(errorLabel)
        view.addSubview(reconnectButton)
        
        // 设置约束 - Setup constraints
        NSLayoutConstraint.activate([
            // 设备名称 - Device name
            deviceNameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            deviceNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            deviceNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // MAC地址 - MAC address
            deviceMacLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 12),
            deviceMacLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            deviceMacLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // 连接状态 - Connection state
            connectionStateLabel.topAnchor.constraint(equalTo: deviceMacLabel.bottomAnchor, constant: 40),
            connectionStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            connectionStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // 进度指示器 - Activity indicator
            activityIndicator.topAnchor.constraint(equalTo: connectionStateLabel.bottomAnchor, constant: 30),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // 错误信息 - Error message
            errorLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 30),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // 重新连接按钮 - Reconnect button
            reconnectButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 30),
            reconnectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reconnectButton.widthAnchor.constraint(equalToConstant: 200),
            reconnectButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    /// 设置按钮动作 - Setup button actions
    private func setupActions() {
        reconnectButton.addTarget(self, action: #selector(reconnectButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Connection Logic
    /// 开始连接设备 - Start connecting device
    private func startConnection() {
        guard !isConnecting else {
            print("⚠️ 已在连接中，跳过 - Already connecting, skip")
            return
        }
        
        isConnecting = true
        updateUIForConnecting()
        
        // 创建设备监听器 - Create device observer
        let deviceObserver = DeviceObserver()
        self.observer = deviceObserver
        
        print("🔌 开始连接设备 - Start connecting device: \(deviceInfo.name) (\(deviceInfo.uuid))")
        
        // 调用SDK连接方法 - Call SDK connection method
        TopStepAIBuds.connectDevice(
            uuid: deviceInfo.uuid,
            connectStyle: .BLE,
            category: deviceInfo.deviceCategory,
            userId: "",
            deviceObserver: deviceObserver
        ) { [weak self] connectState, error, deviceInfo, peripheral in
            guard let self = self else { return }
            
            // 更新 DeviceObserver 的连接状态 - Update DeviceObserver connection state
            deviceObserver.updateConnectionState(state: connectState, peripheral: peripheral)
            
            DispatchQueue.main.async {
                self.isConnecting = false
                
                if let error = error {
                    // 连接失败 - Connection failed
                    self.handleConnectionFailure(error: error)
                } else if connectState == .connected, let device = TopStepAIBuds.shared.earbuds {
                    // 连接成功 - Connection succeeded
                    self.handleConnectionSuccess(device: device, deviceInfo: deviceInfo)
                } else {
                    // 其他状态 - Other states
                    self.updateConnectionState(connectState)
                }
            }
        }
    }
    
    /// 更新连接状态UI - Update connection state UI
    private func updateConnectionState(_ state: TSBTConnectState) {
        switch state {
        case .connecting:
            connectionStateLabel.text = "连接中..."
            connectionStateLabel.textColor = .systemBlue
        case .connected:
            connectionStateLabel.text = "已连接"
            connectionStateLabel.textColor = .systemGreen
        case .disconnecting:
            connectionStateLabel.text = "断开中..."
            connectionStateLabel.textColor = .systemOrange
        case .disconnected:
            connectionStateLabel.text = "未连接"
            connectionStateLabel.textColor = .systemRed
        @unknown default:
            connectionStateLabel.text = "未知状态"
            connectionStateLabel.textColor = .systemGray
        }
    }
    
    /// 更新UI为连接中状态 - Update UI for connecting state
    private func updateUIForConnecting() {
        connectionStateLabel.text = "连接中..."
        connectionStateLabel.textColor = .systemBlue
        activityIndicator.startAnimating()
        errorLabel.isHidden = true
        reconnectButton.isHidden = true
    }
    
    /// 处理连接成功 - Handle connection success
    private func handleConnectionSuccess(device: TSSBEarbuds, deviceInfo: TSDeviceBaseInfo?) {
        print("✅ 设备连接成功 - Device connected successfully")
        
        // 停止进度指示器 - Stop activity indicator
        activityIndicator.stopAnimating()
        
        // 更新状态 - Update state
        connectionStateLabel.text = "连接成功！"
        connectionStateLabel.textColor = .systemGreen
        
        // 保存设备到缓存 - Save device to cache
        if let deviceInfo = deviceInfo {
            DeviceCacheManager.shared.saveDevice(deviceInfo)
        }
        
        // 延迟切换到详情页面（设置为根视图控制器）
        // Delay switching to detail page (set as root view controller)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, let observer = self.observer else { return }
            
            // 创建设备详情页面 - Create device detail page
            let detailVC = DeviceDetailViewController(device: device, observer: observer)
            let navController = UINavigationController(rootViewController: detailVC)
            
            // 获取当前窗口并切换根视图控制器 - Get current window and switch root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController = navController
                
                // 添加过渡动画 - Add transition animation
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                
                print("✅ 已切换到设备详情页面 - Switched to device detail page")
            }
        }
    }
    
    /// 处理连接失败 - Handle connection failure
    private func handleConnectionFailure(error: Error) {
        print("❌ 设备连接失败 - Device connection failed: \(error.localizedDescription)")
        
        // 停止进度指示器 - Stop activity indicator
        activityIndicator.stopAnimating()
        
        // 更新状态 - Update state
        connectionStateLabel.text = "连接失败"
        connectionStateLabel.textColor = .systemRed
        
        // 显示错误信息 - Show error message
        errorLabel.text = "错误: \(error.localizedDescription)\nError: \(error.localizedDescription)"
        errorLabel.isHidden = false
        
        // 显示重新连接按钮 - Show reconnect button
        reconnectButton.isHidden = false
    }
    
    /// 重新连接按钮点击 - Reconnect button tapped
    @objc private func reconnectButtonTapped() {
        print("🔄 用户点击重新连接 - User tapped reconnect")
        startConnection()
    }
}

