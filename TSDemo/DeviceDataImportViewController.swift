//
//  DeviceDataImportViewController.swift
//  TSDemo
//
//  数据导入页面占位
//

import UIKit
import TopStepABMateSDK
import RxSwift
import Network

/// 数据导入页面
final class DeviceDataImportViewController: UIViewController {
    
    // MARK: - Types
    private enum Section: Int, CaseIterable {
        case imported
        case device
        
        var title: String {
            switch self {
            case .imported:
                return "已导入文件"
            case .device:
                return "设备可导入文件"
            }
        }
    }
    
    // MARK: - Properties
    private let device: TSSBEarbuds
    private let observer: DeviceObserver
    
    private let mediaTypes: [ImportedMediaType] = ImportedMediaType.allCases
    private var importedMediaNames: [ImportedMediaType: [String]] = [:]
    private var deviceMediaCount: (pic: UInt32, video: UInt32, audio: UInt32)?
    
    private let disposeBag = DisposeBag()
    private var isRequestingMediaCount = false
    private var isImporting = false
    private var hasEnteredFileTransferMode = false
    private var importDisposeBag = DisposeBag()
    private var importAlert: UIAlertController?
    private var importAlertHasCancelAction = false
    private var currentImportProgressText = "准备中..."
    private var currentImportErrorText = ""
    private var currentImportWifiStateText = "未知"
    private var currentImportWifiAddressText: String?
    private var currentImportBaseURL: URL?
    private let importWiFiConfig = (mode: UInt8(1), ssid: "GlassImportTest", password: "12345678", channel: UInt8(0))
    private var activeHTTPDownloaders: [UUID: HTTPDownloader] = [:]
    
    // MARK: - UI Elements
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MediaCell")
        return tableView
    }()
    
    private let requestCountButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("刷新设备媒体数量", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .systemGray5
        button.setTitleColor(.label, for: .normal)
        button.setTitleColor(.secondaryLabel, for: .disabled)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let importButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("导入数据", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.setTitle("导入数据", for: .disabled)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .disabled)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var buttonStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [requestCountButton, importButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
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
        title = "数据导入"
        view.backgroundColor = .systemBackground
        setupUI()
        setupActions()
        bindObserver()
        refreshImportedMedia(animated: false)
        applyDeviceMediaCount(observer.mediaCount.value)
        
        if observer.mediaCount.value == nil {
            requestDeviceMediaCount(silent: true)
        } else {
            updateImportButtonState()
        }
        
        print("📦 DeviceDataImportViewController init with device: \(device)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshImportedMedia(animated: false)
    }
    
    // MARK: - Setup
    private func setupUI() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        
        view.addSubview(tableView)
        view.addSubview(buttonStack)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -16),
            
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
        
        requestCountButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        importButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        
        importButton.isEnabled = false
        importButton.alpha = 0.5
        updateRequestButtonAppearance()
    }
    
    private func setupActions() {
        requestCountButton.addTarget(self, action: #selector(handleRequestMediaCount), for: .touchUpInside)
        importButton.addTarget(self, action: #selector(handleImportTapped), for: .touchUpInside)
    }
    
    private func bindObserver() {
        observer.mediaCount
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] count in
                self?.applyDeviceMediaCount(count)
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Data Handling
    private func refreshImportedMedia(animated: Bool = true) {
        guard isViewLoaded else { return }
        var updated: [ImportedMediaType: [String]] = [:]
        mediaTypes.forEach { type in
            updated[type] = ImportedMediaStore.shared.fileNames(for: type)
        }
        importedMediaNames = updated
        let animation: UITableView.RowAnimation = animated ? .automatic : .none
        tableView.reloadSections(IndexSet(integer: Section.imported.rawValue), with: animation)
    }
    
    private func applyDeviceMediaCount(_ count: (pic: UInt32, video: UInt32, audio: UInt32)?) {
        deviceMediaCount = count
        guard isViewLoaded else { return }
        tableView.reloadSections(IndexSet(integer: Section.device.rawValue), with: .none)
        updateImportButtonState()
    }
    
    private func importedCount(for type: ImportedMediaType) -> Int {
        return importedMediaNames[type]?.count ?? 0
    }
    
    private func deviceCount(for type: ImportedMediaType) -> UInt32? {
        guard let count = deviceMediaCount else { return nil }
        switch type {
        case .image:
            return count.pic
        case .video:
            return count.video
        case .audio:
            return count.audio
        }
    }
    
    // MARK: - Actions
    @objc private func handleRequestMediaCount() {
        requestDeviceMediaCount(silent: false)
    }
    
    private func requestDeviceMediaCount(silent: Bool) {
        guard !isRequestingMediaCount else { return }
        guard !isImporting else {
            if !silent {
                presentMessage(title: "导入进行中", message: "请等待当前导入流程完成后再刷新设备媒体数量。")
            }
            return
        }
        isRequestingMediaCount = true
        updateRequestButtonAppearance()
        
        device.commandManager.queryABMateMediaCount { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRequestingMediaCount = false
                self.updateRequestButtonAppearance()
                
                if let error = error {
                    if !silent {
                        self.presentMessage(title: "查询失败", message: error.localizedDescription)
                    }
                    return
                }
                
                if !success {
                    if !silent {
                        self.presentMessage(title: "查询失败", message: "设备执行失败")
                    }
                    return
                }
                
                if !silent {
                    self.presentMessage(title: "请求已发送", message: "等待设备上报媒体数量")
                }
            }
        }
    }
    
    @objc private func handleImportTapped() {
        guard !isImporting else { return }
        startImportProcess()
    }
    
    private func updateImportButtonState() {
        let total = deviceMediaCount.map {
            UInt64($0.pic) + UInt64($0.video) + UInt64($0.audio)
        } ?? 0
        let enabled = total > 0 && !isImporting
        importButton.isEnabled = enabled
        importButton.alpha = enabled ? 1.0 : 0.5
    }
    
    private func updateRequestButtonAppearance() {
        let loading = isRequestingMediaCount
        let enabled = !loading && !isImporting
        requestCountButton.isEnabled = enabled
        requestCountButton.alpha = enabled ? 1.0 : 0.6
        let title = loading ? "请求中..." : "刷新设备媒体数量"
        requestCountButton.setTitle(title, for: .normal)
        requestCountButton.setTitle(title, for: .disabled)
    }
    
    private func presentMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Import Workflow
    private struct ImportProcessError: Error {
        let message: String
    }
    
    private func startImportProcess() {
        let total = deviceMediaCount.map { UInt64($0.pic) + UInt64($0.video) + UInt64($0.audio) } ?? 0
        guard total > 0 else {
            presentMessage(title: "暂无可导入文件", message: "请先刷新设备媒体数量后再尝试导入。")
            return
        }
        guard !isRequestingMediaCount else {
            presentMessage(title: "请稍候", message: "正在刷新设备媒体数量，请稍后再尝试导入。")
            return
        }
        print("📥 [Import] 开始导入流程，待导入文件数：\(total)")
        isImporting = true
        importDisposeBag = DisposeBag()
        currentImportProgressText = "准备开始导入..."
        currentImportErrorText = ""
        currentImportWifiStateText = wifiStateText(for: observer.wifiState.value)
        currentImportWifiAddressText = observer.wifiAddress.value.isEmpty ? nil : observer.wifiAddress.value
        currentImportBaseURL = nil
        importAlertHasCancelAction = false
        hasEnteredFileTransferMode = false
        updateImportButtonState()
        updateRequestButtonAppearance()
        presentImportAlert()
        observeImportRelays()
        configureDeviceWiFi()
    }
    
    private func presentImportAlert() {
        let alert = UIAlertController(title: "导入进度", message: composeImportAlertMessage(), preferredStyle: .alert)
        importAlert = alert
        present(alert, animated: true)
    }
    
    private func observeImportRelays() {
        observer.wifiState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                guard let self = self else { return }
                self.currentImportWifiStateText = self.wifiStateText(for: state)
                self.updateImportAlert()
            })
            .disposed(by: importDisposeBag)
        
        observer.wifiAddress
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] address in
                guard let self = self else { return }
                self.currentImportWifiAddressText = address.isEmpty ? nil : address
                self.updateImportAlert()
            })
            .disposed(by: importDisposeBag)
    }
    
    private func configureDeviceWiFi() {
        updateImportAlert(progress: "配置设备 Wi-Fi...", error: "")
        device.commandManager.setSystemWiFi(
            model: NSNumber(value: importWiFiConfig.mode),
            channel: NSNumber(value: importWiFiConfig.channel),
            ssid: importWiFiConfig.ssid,
            password: importWiFiConfig.password
        ) { [weak self] code, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    print("❌ [Import] 配置 Wi-Fi 失败：\(error.localizedDescription)")
                    self.handleImportFailure(message: "配置 Wi-Fi 失败：\(error.localizedDescription)")
                    return
                }
                guard code == 0 else {
                    let message = self.wifiConfigErrorDescription(for: code)
                    print("❌ [Import] 配置 Wi-Fi 失败，返回码：\(code)，说明：\(message)")
                    self.handleImportFailure(message: "配置 Wi-Fi 失败：\(message)")
                    return
                }
                print("✅ [Import] Wi-Fi 配置成功")
                self.startFileTransferMode()
            }
        }
    }
    
    private func startFileTransferMode() {
        updateImportAlert(progress: "开启文件传输模式...", error: "")
        device.commandManager.startFileTransfer { [weak self] code, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    print("❌ [Import] 开启文件传输失败：\(error.localizedDescription)")
                    self.handleImportFailure(message: "开启文件传输失败：\(error.localizedDescription)")
                    return
                }
                guard code == 0 else {
                    let message = self.fileTransferErrorDescription(for: code)
                    print("❌ [Import] 开启文件传输失败，返回码：\(code)，说明：\(message)")
                    self.handleImportFailure(message: "开启文件传输失败：\(message)")
                    return
                }
                print("✅ [Import] 已进入文件传输模式")
                self.hasEnteredFileTransferMode = true
                self.waitForHotspotAndConnect()
            }
        }
    }
    
    private func waitForHotspotAndConnect() {
        updateImportAlert(progress: "等待设备热点/Wi-Fi 准备就绪...", error: "")
        if let state = observer.wifiState.value, isWifiReadyForConnection(state) {
            connectToDeviceWiFi()
            return
        }
        waitForWifiState(targetStates: [.hotPotOpen, .wifiDirectOpen, .wifiDirectConnected], timeout: 20) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                print("✅ [Import] 设备热点/Wi-Fi 已就绪")
                self.connectToDeviceWiFi()
            case .failure(let error):
                self.handleImportFailure(message: error.message)
            }
        }
    }
    
    private func connectToDeviceWiFi() {
        let delay: TimeInterval = 3
        updateImportAlert(progress: "等待热点稳定，\(Int(delay)) 秒后尝试连接...", error: "")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isImporting else { return }
            self.updateImportAlert(progress: "连接热点中...", error: "")
            TSSBWiFiManager.connectToWifi(ssid: self.importWiFiConfig.ssid, password: self.importWiFiConfig.password, isweb: false) { [weak self] success in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    guard success else {
                        print("❌ [Import] 手机连接热点失败")
                        self.handleImportFailure(message: "手机连接热点失败")
                        return
                    }
                    print("✅ [Import] 手机热点连接请求已发出")
                    self.waitForWifiAddress()
                }
            }
        }
    }
    
    private func waitForWifiAddress() {
        updateImportAlert(progress: "等待设备返回访问地址...", error: "")
        let currentAddress = observer.wifiAddress.value
        if !currentAddress.isEmpty {
            handleWifiAddress(currentAddress)
            return
        }
        waitForWifiAddress(timeout: 20) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let address):
                print("✅ [Import] 收到设备访问地址：\(address)")
                self.handleWifiAddress(address)
            case .failure(let error):
                self.handleImportFailure(message: error.message)
            }
        }
    }
    
    private func handleWifiAddress(_ address: String) {
        guard let baseURL = URL(string: address) else {
            print("❌ [Import] 访问地址无效：\(address)")
            handleImportFailure(message: "无效的访问地址：\(address)")
            return
        }
        currentImportBaseURL = baseURL
        updateImportAlert(progress: "获取文件列表...", error: "")
        fetchRemoteFileList(from: baseURL) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let files):
                if files.isEmpty {
                    print("ℹ️ [Import] 设备上没有可导入的文件")
                    self.updateImportAlert(progress: "没有可导入的文件，准备关闭文件传输...", error: "")
                    self.closeFileTransfer(afterDownloading: 0)
                } else {
                    print("📄 [Import] 设备文件列表：\(files)")
                    self.updateImportAlert(progress: "共检测到 \(files.count) 个文件，开始下载...", error: "")
                    self.downloadFiles(files, baseURL: baseURL)
                }
            case .failure(let error):
                self.handleImportFailure(message: error.message)
            }
        }
    }
    
    private func fetchRemoteFileList(from baseURL: URL, completion: @escaping (Result<[String], ImportProcessError>) -> Void) {
        let listURL = baseURL.appendingPathComponent("media.config")
        downloadHTTPData(from: listURL) { result in
            switch result {
            case .success(let data):
                let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
                let files = text
                    .components(separatedBy: CharacterSet.newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                completion(.success(files))
            case .failure(let error):
                completion(.failure(ImportProcessError(message: "获取文件列表失败：\(error.localizedDescription)")))
            }
        }
    }
    
    private func downloadFiles(_ fileNames: [String], baseURL: URL) {
        var index = 0
        var downloaded = 0
        
        func downloadNext() {
            if index >= fileNames.count {
                closeFileTransfer(afterDownloading: downloaded)
                return
            }
            let name = fileNames[index]
            updateImportAlert(progress: "下载文件 \(index + 1)/\(fileNames.count)：\(name)", error: "")
            downloadSingleFile(remoteName: name, baseURL: baseURL) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    downloaded += 1
                    self.refreshImportedMedia(animated: false)
                    index += 1
                    downloadNext()
                case .failure(let error):
                    self.handleImportFailure(message: error.message)
                }
            }
        }
        
        downloadNext()
    }
    
    private func downloadSingleFile(remoteName: String, baseURL: URL, completion: @escaping (Result<Void, ImportProcessError>) -> Void) {
        let remoteURL = baseURL.appendingPathComponent(remoteName)
        downloadHTTPData(from: remoteURL) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                let localName = self.sanitizedFileName(from: remoteName)
                guard let type = self.mediaType(for: localName) else {
                    completion(.failure(ImportProcessError(message: "不支持的文件类型：\(localName)")))
                    return
                }
                
                DispatchQueue.global(qos: .utility).async {
                    do {
                        try ImportedMediaStore.shared.save(data: data, fileName: localName, type: type)
                        DispatchQueue.main.async {
                            completion(.success(()))
                        }
                    } catch {
                        DispatchQueue.main.async {
                            completion(.failure(ImportProcessError(message: "保存 \(localName) 失败：\(error.localizedDescription)")))
                        }
                    }
                }
            case .failure(let error):
                completion(.failure(ImportProcessError(message: "下载 \(remoteName) 失败：\(error.localizedDescription)")))
            }
        }
    }
    
    private func closeFileTransfer(afterDownloading count: Int) {
        updateImportAlert(progress: "关闭文件传输...", error: "")
        device.commandManager.shutDownABMateRecord { [weak self] code, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.hasEnteredFileTransferMode = false
                if let error = error {
                    print("❌ [Import] 关闭文件传输失败：\(error.localizedDescription)")
                    self.handleImportFailure(message: "关闭文件传输失败：\(error.localizedDescription)")
                    return
                }
                guard code == 0 else {
                    print("❌ [Import] 关闭文件传输失败，返回码：\(code)")
                    self.handleImportFailure(message: "关闭文件传输失败：返回码 \(code)")
                    return
                }
                print("✅ [Import] 文件传输模式已关闭")
                self.handleImportSuccess(downloadedCount: count)
            }
        }
    }
    
    private func handleImportSuccess(downloadedCount: Int) {
        updateImportAlert(progress: "导入完成，共导入 \(downloadedCount) 个文件", error: "")
        finalizeImportState()
        refreshImportedMedia(animated: false)
        requestDeviceMediaCount(silent: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.dismissImportAlert()
        }
    }
    
    private func handleImportFailure(message: String) {
        print("❌ [Import] 导入流程失败：\(message)")
        let finalMessage = augmentedFailureMessage(for: message)
        updateImportAlert(progress: "导入已停止", error: finalMessage)
        attemptShutdownIfNeeded()
        finalizeImportState()
        addCancelActionIfNeeded()
    }
    
    private func finalizeImportState() {
        isImporting = false
        importDisposeBag = DisposeBag()
        currentImportBaseURL = nil
        updateImportButtonState()
        updateRequestButtonAppearance()
    }
    
    private func augmentedFailureMessage(for message: String) -> String {
        var result = message
        
        let hotspotKeywords = ["连接热点", "等待热点稳定", "等待设备返回访问地址"]
        let shouldAppendHotspotHint = hotspotKeywords.contains { keyword in
            currentImportProgressText.contains(keyword)
        }
        let hotspotHint = "请检查在Xcode中是否配置了Hotspot权限。"
        if shouldAppendHotspotHint, !result.contains(hotspotHint) {
            result.append("\n\(hotspotHint)")
        }
        
        let busyHint = "设备可能仍在处理文件，关闭完成后会通过通知回调结果"
        if result.contains("系统繁忙") && !result.contains(busyHint) {
            result.append("\n\(busyHint)")
        }
        
        return result
    }
    
    private func downloadHTTPData(from url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        let downloader = HTTPDownloader(url: url)
        let id = downloader.id
        activeHTTPDownloaders[id] = downloader
        downloader.start { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                completion(result)
                self?.activeHTTPDownloaders.removeValue(forKey: id)
            }
        }
    }
    
    private func addCancelActionIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let alert = self.importAlert, !self.importAlertHasCancelAction else { return }
            self.importAlertHasCancelAction = true
            let action = UIAlertAction(title: "关闭", style: .cancel) { [weak self] _ in
                self?.dismissImportAlert()
            }
            alert.addAction(action)
        }
    }
    
    private func dismissImportAlert() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let alert = self.importAlert else { return }
            alert.dismiss(animated: true) {
                self.importAlert = nil
            }
        }
    }
    
    private func attemptShutdownIfNeeded() {
        guard hasEnteredFileTransferMode else { return }
        hasEnteredFileTransferMode = false
        device.commandManager.shutDownABMateRecord { _, _ in }
    }
    
    private func waitForWifiState(targetStates: [TSSBEarbudsWiFiState], timeout: TimeInterval, completion: @escaping (Result<Void, ImportProcessError>) -> Void) {
        if let current = observer.wifiState.value, targetStates.contains(current) {
            completion(.success(()))
            return
        }
        let milliseconds = max(1, Int(timeout * 1000))
        observer.wifiState
            .asObservable()
            .compactMap { $0 }
            .filter { targetStates.contains($0) }
            .take(1)
            .timeout(.milliseconds(milliseconds), scheduler: MainScheduler.instance)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onNext: { _ in completion(.success(())) },
                onError: { error in
                    if case RxError.timeout = error {
                        completion(.failure(ImportProcessError(message: "等待设备热点/Wi-Fi 就绪超时")))
                    } else {
                        completion(.failure(ImportProcessError(message: "监听热点状态失败：\(error.localizedDescription)")))
                    }
                }
            )
            .disposed(by: importDisposeBag)
    }
    
    private func waitForWifiAddress(timeout: TimeInterval, completion: @escaping (Result<String, ImportProcessError>) -> Void) {
        let current = observer.wifiAddress.value
        if !current.isEmpty {
            completion(.success(current))
            return
        }
        let milliseconds = max(1, Int(timeout * 1000))
        observer.wifiAddress
            .asObservable()
            .filter { !$0.isEmpty }
            .take(1)
            .timeout(.milliseconds(milliseconds), scheduler: MainScheduler.instance)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onNext: { address in completion(.success(address)) },
                onError: { error in
                    if case RxError.timeout = error {
                        completion(.failure(ImportProcessError(message: "等待设备提供访问地址超时")))
                    } else {
                        completion(.failure(ImportProcessError(message: "监听访问地址失败：\(error.localizedDescription)")))
                    }
                }
            )
            .disposed(by: importDisposeBag)
    }
    
    private func updateImportAlert(progress: String? = nil, error: String? = nil) {
        if let progress = progress {
            currentImportProgressText = progress
        }
        if let error = error {
            currentImportErrorText = error
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let alert = self.importAlert else { return }
            alert.message = self.composeImportAlertMessage()
        }
    }
    
    private func composeImportAlertMessage() -> String {
        var lines: [String] = [
            "进度：\(currentImportProgressText)",
            "Wi-Fi：\(currentImportWifiStateText)"
        ]
        if let address = currentImportWifiAddressText, !address.isEmpty {
            lines.append("地址：\(address)")
        }
        let errorText = currentImportErrorText.isEmpty ? "无" : currentImportErrorText
        lines.append("错误：\(errorText)")
        return lines.joined(separator: "\n")
    }
    
    private func wifiStateText(for state: TSSBEarbudsWiFiState?) -> String {
        guard let state = state else { return "未知" }
        switch state {
        case .hotPotClose:
            return "热点关闭"
        case .hotPotOpen:
            return "热点已开启"
        case .wifiDirectOpen:
            return "Wi-Fi 打开"
        case .wifiDirectConnected:
            return "Wi-Fi 已连接"
        case .wifiDirectFailed:
            return "Wi-Fi 连接失败"
        case .wifiDirectTimeout:
            return "Wi-Fi 连接超时"
        @unknown default:
            return "未知状态(\(state.rawValue))"
        }
    }
    
    private func isWifiReadyForConnection(_ state: TSSBEarbudsWiFiState) -> Bool {
        switch state {
        case .hotPotOpen, .wifiDirectOpen, .wifiDirectConnected:
            return true
        default:
            return false
        }
    }
    
    private func wifiConfigErrorDescription(for code: Int) -> String {
        switch code {
        case 0x01:
            return "TLV 数据不合法"
        case 0x02:
            return "SSID 或密码过长"
        case 0x03:
            return "SSID 或密码过短"
        case 0x04:
            return "SSID 非合法 UTF-8"
        case 0x05:
            return "设备不支持该模式"
        case 0x06:
            return "无法设置到该频道"
        default:
            return "未知错误码 \(code)"
        }
    }
    
    private func fileTransferErrorDescription(for code: Int) -> String {
        switch code {
        case 0:
            return "成功"
        case 1:
            return "系统处于其他状态"
        case 2:
            return "Wi-Fi 凭据为空，无法连接网络或开启热点"
        case 3:
            return "Wi-Fi 芯片启动失败"
        case 4:
            return "电量过低，无法启动 Wi-Fi"
        default:
            return "未知错误码 \(code)"
        }
    }
    
    private func sanitizedFileName(from remoteName: String) -> String {
        let lastComponent = (remoteName as NSString).lastPathComponent
        let cleaned = lastComponent.replacingOccurrences(of: "..", with: "_")
        return cleaned.isEmpty ? UUID().uuidString : cleaned
    }
    
    private func mediaType(for fileName: String) -> ImportedMediaType? {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "bmp", "tif", "tiff":
            return .image
        case "mp4", "mov", "m4v", "mkv", "avi", "ts":
            return .video
        case "mp3", "m4a", "aac", "wav", "flac", "opus", "ogg":
            return .audio
        default:
            return nil
        }
    }
    
    private func showImportedMediaList(for type: ImportedMediaType) {
        let names = importedMediaNames[type] ?? []
        let title = "\(type.displayName)（\(names.count) 个）"
        let message: String
        if names.isEmpty {
            message = "暂无已导入的\(type.displayName)"
        } else {
            message = names.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }
}

private final class HTTPDownloader {
    let id = UUID()
    
    private enum DownloaderError: LocalizedError {
        case invalidURL
        case unsupportedScheme
        case invalidPort
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的下载地址"
            case .unsupportedScheme:
                return "仅支持HTTP协议"
            case .invalidPort:
                return "无效的端口号"
            }
        }
    }
    
    private let url: URL
    private var connection: NWConnection?
    private var completion: ((Result<Data, Error>) -> Void)?
    private var headerBuffer = Data()
    private var bodyData = Data()
    private var headerParsed = false
    private var expectedContentLength: Int64 = -1
    private var isFinished = false
    private let separatorData = "\r\n\r\n".data(using: .utf8)!
    private let queue = DispatchQueue(label: "com.tsdemo.httpdownloader", qos: .utility)
    
    init(url: URL) {
        self.url = url
    }
    
    func start(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let host = url.host else {
            completion(.failure(DownloaderError.invalidURL))
            return
        }
        guard (url.scheme ?? "http").lowercased() == "http" else {
            completion(.failure(DownloaderError.unsupportedScheme))
            return
        }
        let portValue = url.port ?? 80
        guard portValue > 0, portValue < 65536, let nwPort = NWEndpoint.Port(rawValue: UInt16(portValue)) else {
            completion(.failure(DownloaderError.invalidPort))
            return
        }
        
        self.completion = completion
        
        var path = url.path
        if path.isEmpty { path = "/" }
        if let query = url.query, !query.isEmpty {
            path += "?\(query)"
        }
        
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        self.connection = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.sendRequest(path: path, host: host)
            case .failed(let error):
                self.finish(.failure(error))
            case .cancelled:
                self.finish(.failure(NWError.posix(.ECANCELED)))
            case .waiting(let error):
                if case let NWError.posix(posixError) = error,
                   posixError == .ENETDOWN || posixError == .ENETUNREACH {
                    return
                }
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func sendRequest(path: String, host: String) {
        guard let connection = connection else { return }
        var request = "GET \(path) HTTP/1.1\r\n"
        request += "Host: \(host)\r\n"
        request += "Connection: close\r\n"
        request += "\r\n"
        let requestData = Data(request.utf8)
        
        connection.send(content: requestData, completion: .contentProcessed { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.finish(.failure(error))
                return
            }
            self.receiveNext()
        })
    }
    
    private func receiveNext() {
        guard let connection = connection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                self.finish(.failure(error))
                return
            }
            
            if let data = data, !data.isEmpty {
                self.processReceivedData(data)
            }
            
            if isComplete {
                self.finish(.success(self.bodyData))
            } else {
                self.receiveNext()
            }
        }
    }
    
    private func processReceivedData(_ data: Data) {
        if headerParsed {
            bodyData.append(data)
            return
        }
        
        headerBuffer.append(data)
        
        if let range = headerBuffer.range(of: separatorData) {
            let headerData = headerBuffer.subdata(in: 0..<range.lowerBound)
            let bodyStartIndex = range.upperBound
            let bodyPart = headerBuffer.subdata(in: bodyStartIndex..<headerBuffer.count)
            headerParsed = true
            parseHeaders(from: headerData)
            bodyData.append(bodyPart)
            headerBuffer.removeAll(keepingCapacity: false)
        }
    }
    
    private func parseHeaders(from data: Data) {
        guard let headerString = String(data: data, encoding: .utf8) else { return }
        let lines = headerString.components(separatedBy: "\r\n")
        for line in lines {
            let parts = line.components(separatedBy: ": ")
            guard parts.count == 2 else { continue }
            if parts[0].lowercased() == "content-length", let length = Int64(parts[1]) {
                expectedContentLength = length
            }
        }
    }
    
    private func finish(_ result: Result<Data, Error>) {
        guard !isFinished else { return }
        isFinished = true
        connection?.cancel()
        connection = nil
        completion?(result)
        completion = nil
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension DeviceDataImportViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mediaTypes.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        return section.title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MediaCell", for: indexPath)
        guard let section = Section(rawValue: indexPath.section) else {
            return cell
        }
        let type = mediaTypes[indexPath.row]
        var content = UIListContentConfiguration.valueCell()
        content.image = UIImage(systemName: type.systemImageName)
        content.imageProperties.tintColor = .systemBlue
        content.text = type.displayName
        content.textProperties.font = .systemFont(ofSize: 16, weight: .medium)
        content.secondaryTextProperties.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        content.secondaryTextProperties.color = .label
        
        switch section {
        case .imported:
            let count = importedCount(for: type)
            content.secondaryText = "\(count) 个"
            cell.selectionStyle = count > 0 ? .default : .none
            cell.accessoryType = count > 0 ? .disclosureIndicator : .none
        case .device:
            if let count = deviceCount(for: type) {
                content.secondaryText = "\(count) 个"
            } else {
                content.secondaryText = "--"
            }
            cell.selectionStyle = .none
            cell.accessoryType = .none
        }
        
        cell.contentConfiguration = content
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section), section == .imported else { return }
        let type = mediaTypes[indexPath.row]
        guard importedCount(for: type) > 0 else { return }
        showImportedMediaList(for: type)
    }
}

// MARK: - ImportedMediaType Helpers
private extension ImportedMediaType {
    var displayName: String {
        switch self {
        case .image:
            return "图片"
        case .video:
            return "视频"
        case .audio:
            return "录音"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .image:
            return "photo.on.rectangle"
        case .video:
            return "video"
        case .audio:
            return "waveform"
        }
    }
}
