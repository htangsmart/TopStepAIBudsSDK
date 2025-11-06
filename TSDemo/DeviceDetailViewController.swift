//
//  DeviceDetailViewController.swift
//  TSDemo
//
//  设备详情页面 - Device Detail View Controller
//  展示已连接设备的详细信息，通过 RxSwift 实现数据绑定实时更新
//  Displays detailed information of connected device, implements real-time updates via RxSwift data binding
//

import UIKit
import RxSwift
import RxCocoa
import TopStepABMateSDK

/// 设备详情视图控制器
/// Device detail view controller
class DeviceDetailViewController: UIViewController {
    
    // MARK: - Properties
    /// 已连接的设备对象 - Connected device object
    private let device: TSSBEarbuds
    
    /// 设备监听器 - Device observer
    private let observer: DeviceObserver
    
    /// RxSwift 订阅管理 - RxSwift subscription management
    private let disposeBag = DisposeBag()
    
    // MARK: - UI Components
    /// 滚动视图 - Scroll view
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    /// 内容视图 - Content view
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    /// 设备名称标签 - Device name label
    private let deviceNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// MAC地址标签 - MAC address label
    private let macAddressLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// 连接状态指示器 - Connection state indicator
    private let connectionStateView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let connectionStateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.text = "已连接"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// 左耳电量视图 - Left earbud power view
    private let leftPowerView = createPowerView(title: "左耳电量")
    
    /// 右耳电量视图 - Right earbud power view
    private let rightPowerView = createPowerView(title: "右耳电量")
    
    /// 充电仓电量视图 - Charging case power view
    private let hubPowerView = createPowerView(title: "充电仓电量")
    
    /// 固件版本标签 - Firmware version label
    private let firmwareVersionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// 功能列表按钮 - Function list button
    private let functionListButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("功能列表", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    /// 解绑设备按钮 - Unbind device button
    private let unbindButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("解绑设备", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Helper Method
    /// 创建电量视图的辅助方法 - Helper method to create power view
    private static func createPowerView(title: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let powerLabel = UILabel()
        powerLabel.tag = 100 // 用于查找 - For finding
        powerLabel.font = .systemFont(ofSize: 20, weight: .bold)
        powerLabel.textColor = .label
        powerLabel.text = "0%"
        powerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let chargingLabel = UILabel()
        chargingLabel.tag = 101 // 用于查找 - For finding
        chargingLabel.font = .systemFont(ofSize: 12)
        chargingLabel.textColor = .systemGreen
        chargingLabel.text = ""
        chargingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(powerLabel)
        container.addSubview(chargingLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            powerLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            powerLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            chargingLabel.topAnchor.constraint(equalTo: powerLabel.bottomAnchor, constant: 4),
            chargingLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            chargingLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
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
        setupBindings()
        setupActions()
        loadInitialData()
    }
    
    // MARK: - UI Setup
    /// 设置UI界面 - Setup UI
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "设备详情"
        
        // 设置设备基础信息 - Set device basic information
        if let deviceInfo = TopStepAIBuds.shared.earbuds?.deviceInfo {
            deviceNameLabel.text = deviceInfo.name.isEmpty ? "未知设备" : deviceInfo.name
            macAddressLabel.text = "MAC: \(deviceInfo.mac)"
        } else {
            deviceNameLabel.text = "未知设备"
            macAddressLabel.text = "MAC: --"
        }
        
        firmwareVersionLabel.text = "固件版本: 加载中..."
        
        // 添加子视图 - Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(deviceNameLabel)
        contentView.addSubview(macAddressLabel)
        contentView.addSubview(connectionStateView)
        connectionStateView.addSubview(connectionStateLabel)
        contentView.addSubview(leftPowerView)
        contentView.addSubview(rightPowerView)
        contentView.addSubview(hubPowerView)
        contentView.addSubview(firmwareVersionLabel)
        contentView.addSubview(functionListButton)
        contentView.addSubview(unbindButton)
        
        // 设置约束 - Setup constraints
        NSLayoutConstraint.activate([
            // 滚动视图 - Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 内容视图 - Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 设备名称 - Device name
            deviceNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            deviceNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            deviceNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            // MAC地址 - MAC address
            macAddressLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 8),
            macAddressLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            macAddressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            // 连接状态 - Connection state
            connectionStateView.topAnchor.constraint(equalTo: macAddressLabel.bottomAnchor, constant: 20),
            connectionStateView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            connectionStateView.widthAnchor.constraint(equalToConstant: 100),
            connectionStateView.heightAnchor.constraint(equalToConstant: 30),
            
            connectionStateLabel.centerXAnchor.constraint(equalTo: connectionStateView.centerXAnchor),
            connectionStateLabel.centerYAnchor.constraint(equalTo: connectionStateView.centerYAnchor),
            
            // 电量视图 - Power views
            leftPowerView.topAnchor.constraint(equalTo: connectionStateView.bottomAnchor, constant: 40),
            leftPowerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            leftPowerView.widthAnchor.constraint(equalToConstant: 100),
            
            rightPowerView.topAnchor.constraint(equalTo: connectionStateView.bottomAnchor, constant: 40),
            rightPowerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            rightPowerView.widthAnchor.constraint(equalToConstant: 100),
            
            hubPowerView.topAnchor.constraint(equalTo: connectionStateView.bottomAnchor, constant: 40),
            hubPowerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            hubPowerView.widthAnchor.constraint(equalToConstant: 100),
            
            // 固件版本 - Firmware version
            firmwareVersionLabel.topAnchor.constraint(equalTo: leftPowerView.bottomAnchor, constant: 40),
            firmwareVersionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            firmwareVersionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            // 功能列表按钮 - Function list button
            functionListButton.topAnchor.constraint(equalTo: firmwareVersionLabel.bottomAnchor, constant: 40),
            functionListButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            functionListButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            functionListButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 解绑设备按钮 - Unbind device button
            unbindButton.topAnchor.constraint(equalTo: functionListButton.bottomAnchor, constant: 16),
            unbindButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            unbindButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            unbindButton.heightAnchor.constraint(equalToConstant: 50),
            unbindButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    // MARK: - RxSwift Bindings
    /// 设置 RxSwift 数据绑定 - Setup RxSwift data bindings
    private func setupBindings() {
        // 获取电量标签 - Get power labels
        guard let leftPowerLabel = leftPowerView.viewWithTag(100) as? UILabel,
              let leftChargingLabel = leftPowerView.viewWithTag(101) as? UILabel,
              let rightPowerLabel = rightPowerView.viewWithTag(100) as? UILabel,
              let rightChargingLabel = rightPowerView.viewWithTag(101) as? UILabel,
              let hubPowerLabel = hubPowerView.viewWithTag(100) as? UILabel,
              let hubChargingLabel = hubPowerView.viewWithTag(101) as? UILabel else {
            print("⚠️ 无法找到电量标签 - Cannot find power labels")
            return
        }
        
        // 绑定左耳电量 - Bind left earbud power
        observer.leftPower
            .map { "\($0)%" }
            .bind(to: leftPowerLabel.rx.text)
            .disposed(by: disposeBag)
        
        // 绑定左耳充电状态 - Bind left earbud charging status
        observer.leftCharging
            .map { $0 ? "充电中" : "" }
            .bind(to: leftChargingLabel.rx.text)
            .disposed(by: disposeBag)
        
        // 绑定右耳电量 - Bind right earbud power
        observer.rightPower
            .map { "\($0)%" }
            .bind(to: rightPowerLabel.rx.text)
            .disposed(by: disposeBag)
        
        // 绑定右耳充电状态 - Bind right earbud charging status
        observer.rightCharging
            .map { $0 ? "充电中" : "" }
            .bind(to: rightChargingLabel.rx.text)
            .disposed(by: disposeBag)
        
        // 绑定充电仓电量 - Bind charging case power
        observer.hubPower
            .map { "\($0)%" }
            .bind(to: hubPowerLabel.rx.text)
            .disposed(by: disposeBag)
        
        // 绑定充电仓充电状态 - Bind charging case charging status
        observer.hubCharging
            .map { $0 ? "充电中" : "" }
            .bind(to: hubChargingLabel.rx.text)
            .disposed(by: disposeBag)
        
        // 绑定连接状态 - Bind connection state
        observer.connectionState
            .bind(to: connectionStateLabel.rx.text)
            .disposed(by: disposeBag)
        
        // 绑定连接状态颜色 - Bind connection state color
        observer.btConnectState
            .map { state -> UIColor in
                guard let state = state else { return .systemGray }
                switch state {
                case .connected:
                    return .systemGreen
                case .connecting:
                    return .systemBlue
                case .disconnected, .disconnecting:
                    return .systemRed
                @unknown default:
                    return .systemGray
                }
            }
            .subscribe(onNext: { [weak self] color in
                self?.connectionStateView.backgroundColor = color
            })
            .disposed(by: disposeBag)
        
        // 绑定固件版本 - Bind firmware version
        Observable.combineLatest(observer.firmwareVersion, observer.subFirmwareVersion)
            .map { main, sub in
                if sub == "未知" {
                    return "固件版本: \(main)"
                } else {
                    return "固件版本: \(main) (子: \(sub))"
                }
            }
            .bind(to: firmwareVersionLabel.rx.text)
            .disposed(by: disposeBag)
    }
    
    // MARK: - Actions
    /// 设置按钮动作 - Setup button actions
    private func setupActions() {
        // 功能列表按钮 - Function list button
        functionListButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.showFunctionList()
            })
            .disposed(by: disposeBag)
        
        // 解绑设备按钮 - Unbind device button
        unbindButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.unbindDevice()
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Data Loading
    /// 加载初始数据 - Load initial data
    private func loadInitialData() {
        // 获取固件版本 - Get firmware version
        device.commandManager.getMainFirmwareVersion { [weak self] error, version in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 获取主固件版本失败 - Get main firmware version failed: \(error.localizedDescription)")
                } else if let version = version {
                    self?.observer.firmwareVersion.accept(version)
                    print("✅ 主固件版本 - Main firmware version: \(version)")
                }
            }
        }
        
        // 子固件版本在observerSubFirmwareVersionNotify中回调结果
        // 不会在此处直接回调，此处的错误可以忽略
        device.commandManager.getSubFirmwareVersion { [weak self] error, version in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 获取子固件版本失败 - Get sub firmware version failed: \(error.localizedDescription)")
                } else if let version = version {
                    self?.observer.subFirmwareVersion.accept(version)
                    print("✅ 子固件版本 - Sub firmware version: \(version)")
                }
            }
        }
    }
    
    // MARK: - Button Actions
    /// 显示功能列表页面 - Show function list page
    private func showFunctionList() {
        let functionListVC = DeviceFunctionListViewController(device: device, observer: observer)
        navigationController?.pushViewController(functionListVC, animated: true)
    }
    
    /// 解绑设备 - Unbind device
    /// 断开连接、清除缓存并返回设备扫描页面
    /// Disconnect, clear cache and return to device scan page
    private func unbindDevice() {
        let alert = UIAlertController(
            title: "确认解绑",
            message: "解绑后将断开设备连接并清除缓存，需要重新扫描连接设备。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "解绑", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            print("🔓 开始解绑设备 - Start unbinding device")
            
            // 1. 断开设备连接 - Disconnect device
            TopStepAIBuds.disconnectDevice()
            
            // 2. 清除设备缓存 - Clear device cache
            DeviceCacheManager.shared.clearCache()
            
            // 3. 返回到设备扫描页面 - Navigate to device scan page
            // 找到 navigationController 的根视图控制器
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                // 创建新的设备扫描页面 - Create new device scan page
                let scanVC = ScanViewController()
                let navController = UINavigationController(rootViewController: scanVC)
                
                // 切换根视图控制器 - Switch root view controller
                window.rootViewController = navController
                
                // 添加过渡动画 - Add transition animation
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                
                print("✅ 设备已解绑，返回扫描页面 - Device unbound, returned to scan page")
            }
        })
        
        present(alert, animated: true)
    }
}

