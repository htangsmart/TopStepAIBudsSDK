//
//  CommandListViewController.swift
//  TSDemo
//
//  指令列表页面 - Command List View Controller
//  显示某个分类下的所有指令
//

import UIKit
import TopStepABMateSDK
import RxSwift
import RxRelay

/// 指令列表视图控制器
/// Command list view controller
final class CommandListViewController: UIViewController {
    
    private enum MusicAction {
        case play
        case pause
        case next
        case previous
    }
    
    private struct EQPreset {
        let type: Int
        let name: String
        let gains: [NSNumber]
        let isCustom: Bool
    }
    
    private let deviceOperationOptions: [(type: TSSBEarbudsDeviceOperationType, title: String)] = [
        (.leftShortPress, "左耳 - 单击"),
        (.rightShortPress, "右耳 - 单击"),
        (.leftDoubleClick, "左耳 - 双击"),
        (.rightDoubleClick, "右耳 - 双击"),
        (.leftTripleClick, "左耳 - 三击"),
        (.rightTripleClick, "右耳 - 三击"),
        (.leftLongPress, "左耳 - 长按"),
        (.rightLongPress, "右耳 - 长按")
    ]
    
    private let deviceFunctionOptions: [(type: TSSBEarbudsKeyFunction, title: String)] = [
        (.none, "无"),
        (.redial, "回拨电话"),
        (.voiceAssistant, "语音助手"),
        (.previous, "上一曲"),
        (.next, "下一曲"),
        (.volumeUp, "音量 +"),
        (.volumeDown, "音量 -"),
        (.playPause, "播放 / 暂停"),
        (.gameMode, "切换游戏模式"),
        (.ancSetting, "ANC 设置"),
        (.takePhotoSetting, "拍照"),
        (.continuousShooting, "连拍"),
        (.startOrStopRecording, "开始 / 停止录像"),
        (.startOrStopAudioRecord, "开始 / 停止录音"),
        (.LocalOrBTPlaySwitch, "本地 / 蓝牙播放切换")
    ]
    
    private let remoteCameraOptions: [(state: TSSBRemoteCameraState, title: String)] = [
        (.enterCamera, "进入相机"),
        (.exitCamera, "退出相机")
    ]
    
    // MARK: - Properties
    private let device: TSSBEarbuds
    private let observer: DeviceObserver
    private let category: CommandCategory
    private let commands: [TSSBEarbudsCommand]
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var commandValueMap: [TSSBEarbudsCommand: String] = [:]
    private var commandIndexMap: [TSSBEarbudsCommand: Int] = [:]
    private var eqPresets: [EQPreset] = []
    private var isLoadingEQPresets = false
    private var deviceKeyMappings: [TSSBEarbudsDeviceOperationType: TSSBEarbudsKeyFunction] = [:]
    private var isLoadingDeviceKeySettings = false
    private var lastDeviceInfoSummary: String?
    private var lastStandardTimeSummary: String?
    private var operationStatusMap: [TSSBEarbudsCommand: String] = [:]
    private let disposeBag = DisposeBag()
    
    private lazy var standardTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    /// 支持的指令列表（根据设备能力过滤）
    private var supportedCommands: [TSSBEarbudsCommand] = []
    
    // MARK: - Initialization
    init(device: TSSBEarbuds, observer: DeviceObserver, category: CommandCategory) {
        self.device = device
        self.observer = observer
        self.category = category
        self.commands = category.commands
        super.init(nibName: nil, bundle: nil)
        commands.enumerated().forEach { commandIndexMap[$0.element] = $0.offset }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        filterCommandsBySupport()
        setupBindings()
        print("📋 指令列表页面 - Command List Page | category: \(category.name), commands: \(commands.count), supported: \(supportedCommands.count)")
    }
    
    // MARK: - Support Function
    /// 根据设备支持情况过滤指令
    /// Filter commands based on device support
    private func filterCommandsBySupport() {
        let supportFunction = observer.supportFunction.value
        supportedCommands = commands.filter { command in
            CommandHelper.isCommandSupported(command, supportFunction: supportFunction)
        }
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = category.name
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CommandCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupBindings() {
        observer.supportFunction
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.filterCommandsBySupport()
                self.updateAllValues()
                self.tableView.reloadData()
            })
            .disposed(by: disposeBag)
        
        switch category.type {
        case .audio:
            setupAudioBindings()
        case .deviceOperation:
            setupDeviceOperationBindings()
        case .deviceInfo:
            setupDeviceInfoBindings()
        case .media:
            setupMediaBindings()
        case .storage:
            setupStorageBindings()
        case .other:
            setupOtherBindings()
        default:
            updateAllValues()
        }
    }
    
    private func setupAudioBindings() {
        updateAllValues()
        loadEQPresets()
        
        observer.eqMode
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .eq) })
            .disposed(by: disposeBag)
        observer.eqGains
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .eq) })
            .disposed(by: disposeBag)
        observer.isPlaying
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .musicControl) })
            .disposed(by: disposeBag)
        observer.ancMode
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .ancMode) })
            .disposed(by: disposeBag)
        observer.ancGain
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .ancGain) })
            .disposed(by: disposeBag)
        observer.transparencyGain
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .transparencyGain) })
            .disposed(by: disposeBag)
        observer.soundEffect3DEnabled
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .soundEffect3D) })
            .disposed(by: disposeBag)
        observer.bassEngineEnabled
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .bassEngine) })
            .disposed(by: disposeBag)
    }
    
    private func setupDeviceOperationBindings() {
        loadDeviceKeySettings()
        
        observer.workMode
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .workMode) })
            .disposed(by: disposeBag)
        
        Observable.combineLatest(observer.leftInEar.asObservable(), observer.rightInEar.asObservable())
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .inEarDetect) })
            .disposed(by: disposeBag)
        
        observer.ledEnabled
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .ledMode) })
            .disposed(by: disposeBag)
        
        observer.multipointEnabled
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .multipoint) })
            .disposed(by: disposeBag)
        
        observer.voiceRecognitionEnabled
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in self?.updateValue(for: .voiceRecognition) })
            .disposed(by: disposeBag)
        
        observer.keyOperationMap
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] mapping in
                guard let self = self else { return }
                self.deviceKeyMappings = mapping
                self.updateValue(for: .deviceOperation)
            })
            .disposed(by: disposeBag)
        
        updateAllValues()
    }
    
    private func setupDeviceInfoBindings() {
        observer.promptToneType
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.updateValue(for: .promptTone)
            })
            .disposed(by: disposeBag)
        
        updateAllValues()
    }
    
    private func setupMediaBindings() {
        observer.remoteCameraState
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.updateValue(for: .remoteCamera)
            })
            .disposed(by: disposeBag)
        
        updateAllValues()
    }
    
    private func setupStorageBindings() {
        observer.storageSpace
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.updateValue(for: .getStorageInfo)
                self.recordStatus(nil, for: .getStorageInfo)
            })
            .disposed(by: disposeBag)
        
        observer.mediaCount
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                if self.observer.mediaCount.value != nil {
                    self.recordStatus(nil, for: .getMediaCount)
                }
            })
            .disposed(by: disposeBag)
        
        observer.subFirmwareVersion
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.updateValue(for: .subFirmwareVersion)
            })
            .disposed(by: disposeBag)
        
        updateAllValues()
    }
    
    private func setupOtherBindings() {
        observer.deviceWorkStateRaw
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.updateValue(for: .deviceWorkState)
            })
            .disposed(by: disposeBag)
        
        updateAllValues()
    }
    
    private func loadEQPresets() {
        guard category.type == .audio, eqPresets.isEmpty, !isLoadingEQPresets else { return }
        isLoadingEQPresets = true
        device.commandManager.getAllEqualizer { [weak self] error, list in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingEQPresets = false
                if let error = error {
                    print("❌ 加载EQ预设失败: \(error.localizedDescription)")
                    return
                }
                self.eqPresets = list.compactMap { item -> EQPreset? in
                    guard
                        let type = item["type"] as? NSNumber,
                        let name = item["name"] as? String,
                        let gains = item["gains"] as? [NSNumber]
                    else { return nil }
                    let isCustom = (item["isCustom"] as? NSNumber)?.boolValue ?? false
                    return EQPreset(type: type.intValue, name: name, gains: gains, isCustom: isCustom)
                }
                self.updateValue(for: .eq)
            }
        }
    }
    
    private func loadDeviceKeySettings() {
        guard category.type == .deviceOperation, !isLoadingDeviceKeySettings else { return }
        isLoadingDeviceKeySettings = true
        device.commandManager.getDeviceKeySettings { [weak self] error, dictionary in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingDeviceKeySettings = false
                if let error = error {
                    print("❌ 加载按键配置失败: \(error.localizedDescription)")
                    return
                }
                guard let dictionary = dictionary else { return }
                let mapping = self.parseDeviceKeySettings(dictionary)
                if !mapping.isEmpty {
                    self.deviceKeyMappings = mapping
                    self.observer.keyOperationMap.accept(mapping)
                    self.updateValue(for: .deviceOperation)
                }
            }
        }
    }
    
    private func updateAllValues() {
        supportedCommands.forEach { updateValue(for: $0) }
    }
    
    private func updateValue(for command: TSSBEarbudsCommand) {
        guard supportedCommands.contains(command) else { return }
        let existingValue = commandValueMap[command]
        if let newValue = displayValue(for: command) {
            guard existingValue != newValue else { return }
            commandValueMap[command] = newValue
        } else {
            guard existingValue != nil else { return }
            commandValueMap.removeValue(forKey: command)
        }
        
        if let row = supportedCommands.firstIndex(of: command) {
            let indexPath = IndexPath(row: row, section: 0)
            if tableView.indexPathsForVisibleRows?.contains(indexPath) == true {
                tableView.reloadRows(at: [indexPath], with: .none)
            }
        }
    }
    
    private func audioDisplayValue(for command: TSSBEarbudsCommand) -> String {
        switch command {
        case .eq:
            let mode = observer.eqMode.value
            let gains = observer.eqGains.value
            if let preset = eqPresets.first(where: { $0.type == mode }) {
                return preset.name
            }
            if !gains.isEmpty {
                return "自定义 EQ"
            }
            return "模式 \(mode)"
        case .musicControl:
            return observer.isPlaying.value ? "播放中" : "暂停"
        case .ancMode:
            switch observer.ancMode.value {
            case .normal: return "普通模式"
            case .noiseCancellation: return "降噪模式"
            case .transparency: return "通透模式"
            @unknown default: return "未知模式"
            }
        case .ancGain:
            return "等级 \(observer.ancGain.value)"
        case .transparencyGain:
            return "等级 \(observer.transparencyGain.value)"
        case .soundEffect3D:
            return observer.soundEffect3DEnabled.value ? "已开启" : "已关闭"
        case .anc:
            return "使用 ANC 设置"
        case .bassEngine:
            return observer.bassEngineEnabled.value ? "已开启" : "已关闭"
        default:
            return "--"
        }
    }
    
    private func displayValue(for command: TSSBEarbudsCommand) -> String? {
        let categoryValue: String?
        switch category.type {
        case .audio:
            categoryValue = audioDisplayValue(for: command)
        case .deviceOperation:
            categoryValue = deviceOperationDisplayValue(for: command)
        case .deviceInfo:
            categoryValue = deviceInfoDisplayValue(for: command)
        case .media:
            categoryValue = mediaDisplayValue(for: command)
        case .storage:
            categoryValue = storageDisplayValue(for: command)
        case .other:
            categoryValue = otherDisplayValue(for: command)
        default:
            categoryValue = nil
        }
        if let categoryValue = categoryValue {
            return categoryValue
        }
        return operationStatusMap[command]
    }
    
    private func deviceOperationDisplayValue(for command: TSSBEarbudsCommand) -> String? {
        switch command {
        case .deviceOperation:
            return deviceOperationSummaryText()
        case .workMode:
            return workModeDescription(observer.workMode.value)
        case .inEarDetect:
            return inEarStatusText()
        case .ledMode:
            return observer.ledEnabled.value ? "已开启" : "已关闭"
        case .multipoint:
            return observer.multipointEnabled.value ? "已开启" : "已关闭"
        case .voiceRecognition:
            return observer.voiceRecognitionEnabled.value ? "已开启" : "已关闭"
        default:
            return nil
        }
    }
    
    private func deviceInfoDisplayValue(for command: TSSBEarbudsCommand) -> String? {
        switch command {
        case .deviceInfo:
            return lastDeviceInfoSummary ?? "未查询"
        case .promptTone:
            if let type = observer.promptToneType.value {
                return "类型 \(type)"
            }
            return "未获取"
        case .deviceInfoNotify:
            return "监听设备上报"
        case .autoShutdown:
            return nil
        default:
            return nil
        }
    }
    
    private func mediaDisplayValue(for command: TSSBEarbudsCommand) -> String? {
        switch command {
        case .remoteCamera:
            return remoteCameraStateDescription(observer.remoteCameraState.value)
        default:
            return nil
        }
    }
    
    private func storageDisplayValue(for command: TSSBEarbudsCommand) -> String? {
        switch command {
        case .getStorageInfo:
            if let info = observer.storageSpace.value {
                return storageInfoDescription(info)
            }
            return "未查询"
        case .getMediaCount:
            if let count = observer.mediaCount.value {
                return mediaCountDescription(count)
            }
            return "未查询"
        case .setStandardTime:
            return lastStandardTimeSummary ?? "未设置"
        case .subFirmwareVersion:
            let version = observer.subFirmwareVersion.value
            return version.isEmpty ? "未知" : version
        default:
            return nil
        }
    }
    
    private func otherDisplayValue(for command: TSSBEarbudsCommand) -> String? {
        switch command {
        case .deviceWorkState:
            return deviceWorkStateDescription(observer.deviceWorkStateRaw.value)
        default:
            return nil
        }
    }
    
    private func deviceOperationSummaryText() -> String {
        if deviceKeyMappings.isEmpty {
            return "暂无配置"
        }
        let formatted = deviceOperationOptions.compactMap { option -> String? in
            guard let function = deviceKeyMappings[option.type] else { return nil }
            return "\(option.title)：\(deviceFunctionName(function))"
        }
        guard !formatted.isEmpty else {
            return "暂无配置"
        }
        if formatted.count <= 2 {
            return formatted.joined(separator: "，")
        }
        return formatted.prefix(2).joined(separator: "，") + "…"
    }
    
    private func workModeDescription(_ mode: TSSBEarbudsWorkMode) -> String {
        switch mode {
        case .normal:
            return "普通模式"
        case .game:
            return "游戏模式"
        @unknown default:
            return "未知模式"
        }
    }
    
    private func inEarStatusText() -> String {
        let left = observer.leftInEar.value ? "入耳" : "离耳"
        let right = observer.rightInEar.value ? "入耳" : "离耳"
        return "左耳：\(left) | 右耳：\(right)"
    }
    
    private func deviceOperationName(_ operation: TSSBEarbudsDeviceOperationType) -> String {
        if let option = deviceOperationOptions.first(where: { $0.type == operation }) {
            return option.title
        }
        return "操作 \(operation.rawValue)"
    }
    
    private func deviceFunctionName(_ function: TSSBEarbudsKeyFunction) -> String {
        if let option = deviceFunctionOptions.first(where: { $0.type == function }) {
            return option.title
        }
        switch function {
        case .none:
            return "无"
        default:
            return "功能 \(function.rawValue)"
        }
    }
    
    private func remoteCameraStateDescription(_ state: TSSBRemoteCameraState?) -> String {
        guard let state = state else {
            return "未获取"
        }
        switch state {
        case .enterCamera:
            return "已进入相机"
        case .exitCamera:
            return "已退出相机"
        case .takePhotoSuccess:
            return "拍照成功"
        case .takePhotoFailed:
            return "拍照失败"
        @unknown default:
            return "状态 \(state.rawValue)"
        }
    }
    
    private func storageInfoDescription(_ info: (used: UInt32, free: UInt32)) -> String {
        return "已用 \(info.used) MB | 剩余 \(info.free) MB"
    }
    
    private func mediaCountDescription(_ count: (pic: UInt32, video: UInt32, audio: UInt32)) -> String {
        return "图片 \(count.pic) | 视频 \(count.video) | 音频 \(count.audio)"
    }
    
    private func deviceWorkStateDescription(_ raw: UInt8?) -> String {
        guard let raw = raw else { return "未查询" }
        let state = TSSBEarbudsDeviceWorkState(rawValue: raw)
        let name = state.map { deviceWorkStateName($0) } ?? "未知状态"
        return "\(raw) - \(name)"
    }
    
    private func formattedTimezone(minutes: Int16) -> String {
        let sign = minutes >= 0 ? "+" : "-"
        let absolute = abs(Int(minutes))
        let hours = absolute / 60
        let remain = absolute % 60
        return "\(sign)\(String(format: "%02d:%02d", hours, remain))"
    }
    
    private func deviceWorkStateName(_ state: TSSBEarbudsDeviceWorkState) -> String {
        switch state {
        case .reserved: return "保留"
        case .initializing: return "初始化中"
        case .btOrBleWaitingForConnection: return "蓝牙等待连接"
        case .btOrBleConnectedIdle: return "蓝牙已连空闲"
        case .btOrBleDisconnectedIdle: return "蓝牙断开空闲"
        case .calling: return "通话中"
        case .playingLocalMusic: return "本地音乐播放"
        case .aiConversing: return "AI 对话中"
        case .restoringFactorySettings: return "恢复出厂中"
        case .takingPhoto: return "拍照中"
        case .aiTakingPhoto: return "AI 拍照中"
        case .recordingVideo: return "录像中"
        case .recordingAudio: return "录音中"
        case .fileTransferring: return "文件传输中"
        case .streaming: return "流媒体播放"
        case .ota: return "OTA 升级中"
        @unknown default:
            return "未知状态"
        }
    }
    
    private func accessoryType(for command: TSSBEarbudsCommand) -> UITableViewCell.AccessoryType {
        switch category.type {
        case .audio:
            return .disclosureIndicator
        case .deviceOperation:
            switch command {
            case .deviceOperation, .workMode, .findDevice, .voiceRecognition:
                return .disclosureIndicator
            default:
                return .none
            }
        case .deviceInfo:
            switch command {
            case .deviceInfo, .autoShutdown:
                return .disclosureIndicator
            default:
                return .none
            }
        case .media:
            return .disclosureIndicator
        case .storage:
            return .disclosureIndicator
        case .other:
            switch command {
            case .deviceAuthentication, .deviceWorkState:
                return .disclosureIndicator
            default:
                return .none
            }
        default:
            return .none
        }
    }
    
    private func parseDeviceKeySettings(_ dictionary: NSDictionary) -> [TSSBEarbudsDeviceOperationType: TSSBEarbudsKeyFunction] {
        var mapping: [TSSBEarbudsDeviceOperationType: TSSBEarbudsKeyFunction] = [:]
        
        let operationsKeys = ["operations", "operation", "Operations", "Operation"]
        let functionsKeys = ["functions", "function", "Functions", "Function"]
        let operationsArray = operationsKeys.compactMap { dictionary[$0] as? [NSNumber] }.first
        let functionsArray = functionsKeys.compactMap { dictionary[$0] as? [NSNumber] }.first
        if let operations = operationsArray, let functions = functionsArray, operations.count == functions.count {
            for (operationValue, functionValue) in zip(operations, functions) {
                guard
                    let operation = TSSBEarbudsDeviceOperationType(rawValue: operationValue.uint8Value),
                    let function = TSSBEarbudsKeyFunction(rawValue: functionValue.uint8Value)
                else { continue }
                mapping[operation] = function
            }
        }
        
        if mapping.isEmpty {
            for (key, value) in dictionary {
                guard let functionNumber = value as? NSNumber,
                      let operation = parseOperationKey(key),
                      let function = TSSBEarbudsKeyFunction(rawValue: functionNumber.uint8Value) else { continue }
                mapping[operation] = function
            }
        }
        
        if mapping.isEmpty {
            for case let nested as NSDictionary in dictionary.allValues where nested !== dictionary {
                let nestedMapping = parseDeviceKeySettings(nested)
                nestedMapping.forEach { mapping[$0.key] = $0.value }
            }
        }
        
        return mapping
    }
    
    private func parseOperationKey(_ rawKey: Any) -> TSSBEarbudsDeviceOperationType? {
        if let number = rawKey as? NSNumber {
            return TSSBEarbudsDeviceOperationType(rawValue: number.uint8Value)
        }
        guard let string = rawKey as? String else { return nil }
        let sanitized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if sanitized.hasPrefix("0x"), let value = UInt8(sanitized.dropFirst(2), radix: 16) {
            return TSSBEarbudsDeviceOperationType(rawValue: value)
        }
        if let value = UInt8(sanitized, radix: 10) {
            return TSSBEarbudsDeviceOperationType(rawValue: value)
        }
        switch sanitized {
        case "leftshortpress", "left_short_press":
            return .leftShortPress
        case "rightshortpress", "right_short_press":
            return .rightShortPress
        case "leftdoubleclick", "left_double_click":
            return .leftDoubleClick
        case "rightdoubleclick", "right_double_click":
            return .rightDoubleClick
        case "lefttripleclick", "left_triple_click":
            return .leftTripleClick
        case "righttripleclick", "right_triple_click":
            return .rightTripleClick
        case "leftlongpress", "left_long_press":
            return .leftLongPress
        case "rightlongpress", "right_long_press":
            return .rightLongPress
        default:
            return nil
        }
    }
    
    private func recordStatus(_ status: String?, for command: TSSBEarbudsCommand) {
        if let status = status {
            operationStatusMap[command] = status
        } else {
            operationStatusMap.removeValue(forKey: command)
        }
        updateValue(for: command)
    }
    
    private func formattedDeviceInfoPreview(_ info: [String: Any]) -> String {
        if info.isEmpty {
            return "无返回数据"
        }
        let sorted = info.sorted { $0.key < $1.key }
        var lines: [String] = []
        for (index, element) in sorted.enumerated() {
            if index >= 10 {
                lines.append("… 其余 \(sorted.count - 10) 项已省略")
                break
            }
            lines.append("\(element.key): \(element.value)")
        }
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Actions
    private func handleAudioCommand(_ command: TSSBEarbudsCommand) {
        switch command {
        case .eq:
            presentEQSelection()
        case .musicControl:
            presentMusicControlOptions()
        case .ancMode:
            presentANCModeOptions()
        case .ancGain:
            presentNumericInput(title: "设置降噪等级", message: "请输入 0-10 的等级", placeholder: "当前：\(observer.ancGain.value)") { [weak self] value in
                self?.sendUnsupportedCommand(for: command, suggestedValue: value)
            }
        case .transparencyGain:
            presentNumericInput(title: "设置通透等级", message: "请输入 0-10 的等级", placeholder: "当前：\(observer.transparencyGain.value)") { [weak self] value in
                self?.sendUnsupportedCommand(for: command, suggestedValue: value)
            }
        case .soundEffect3D, .anc, .bassEngine:
            sendUnsupportedCommand(for: command, suggestedValue: nil)
        default:
            presentUnsupportedAlert(for: command)
        }
    }
    
    private func handleDeviceOperationCommand(_ command: TSSBEarbudsCommand) {
        switch command {
        case .deviceOperation:
            presentDeviceOperationOptions()
        case .factoryReset:
            presentFactoryResetConfirmation()
        case .workMode:
            presentWorkModeOptions()
        case .findDevice:
            presentFindDeviceOptions()
        case .voiceRecognition:
            presentVoiceRecognitionOptions()
        case .ledMode, .multipoint, .inEarDetect, .autoAnswer, .bluetoothName, .clearPairRecord:
            sendUnsupportedCommand(for: command, suggestedValue: nil)
        default:
            presentUnsupportedAlert(for: command)
        }
    }
    
    private func handleDeviceInfoCommand(_ command: TSSBEarbudsCommand) {
        switch command {
        case .deviceInfo:
            queryDeviceInfo()
        case .autoShutdown:
            presentShutdownConfirmation()
        default:
            presentUnsupportedAlert(for: command)
        }
    }
    
    private func handleMediaCommand(_ command: TSSBEarbudsCommand) {
        switch command {
        case .remoteCamera:
            presentRemoteCameraOptions()
        case .startCameraAndTakephoto:
            presentTakePhotoOptions()
        case .shutDownRecord:
            sendShutdownRecord()
        case .startAudioRecord:
            sendStartAudioRecord()
        case .takeVideoRecord:
            sendTakeVideoRecord()
        default:
            presentUnsupportedAlert(for: command)
        }
    }
    
    private func handleStorageCommand(_ command: TSSBEarbudsCommand) {
        switch command {
        case .getStorageInfo:
            sendQueryStorageInfo()
        case .getMediaCount:
            sendQueryMediaCount()
        case .setStandardTime:
            presentStandardTimeOptions()
        case .subFirmwareVersion:
            sendFetchSubFirmwareVersion()
        default:
            presentUnsupportedAlert(for: command)
        }
    }
    
    private func handleOtherCommand(_ command: TSSBEarbudsCommand) {
        switch command {
        case .deviceAuthentication:
            sendDeviceAuthentication()
        case .deviceWorkState:
            sendDeviceWorkState()
        default:
            presentUnsupportedAlert(for: command)
        }
    }
    
    private func presentEQSelection() {
        if eqPresets.isEmpty {
            let alert = UIAlertController(title: "加载中", message: "正在加载 EQ 预设，请稍候…", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            loadEQPresets()
            return
        }
        let alert = UIAlertController(title: "选择 EQ 预设", message: nil, preferredStyle: .alert)
        eqPresets.forEach { preset in
            let displayName = preset.isCustom ? "\(preset.name)（自定义）" : preset.name
            alert.addAction(UIAlertAction(title: displayName, style: .default) { [weak self] _ in
                self?.sendEQPreset(preset)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func presentMusicControlOptions() {
        let alert = UIAlertController(title: "音乐控制", message: "请选择操作", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "播放", style: .default) { [weak self] _ in
            self?.sendMusicAction(.play)
        })
        alert.addAction(UIAlertAction(title: "暂停", style: .default) { [weak self] _ in
            self?.sendMusicAction(.pause)
        })
        alert.addAction(UIAlertAction(title: "上一首", style: .default) { [weak self] _ in
            self?.sendMusicAction(.previous)
        })
        alert.addAction(UIAlertAction(title: "下一首", style: .default) { [weak self] _ in
            self?.sendMusicAction(.next)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func presentANCModeOptions() {
        let alert = UIAlertController(title: "ANC 模式", message: "请选择模式", preferredStyle: .alert)
        let options: [(String, TSSBEarbudsAncMode)] = [
            ("普通模式", .normal),
            ("降噪模式", .noiseCancellation),
            ("通透模式", .transparency)
        ]
        options.forEach { name, mode in
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.sendANCMode(mode)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    private func presentNumericInput(title: String, message: String, placeholder: String, completion: @escaping (Int) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.keyboardType = .numberPad
            textField.placeholder = placeholder
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            if let text = alert.textFields?.first?.text, let value = Int(text) {
                completion(value)
            }
        })
        present(alert, animated: true)
    }
    
    private func sendEQPreset(_ preset: EQPreset) {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.eq), message: "发送中…")
        device.commandManager.setDeviceEqualizer(mode: UInt8(preset.type), gains: preset.gains) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("发送失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("发送成功"))
                    let gains = preset.gains.map { $0.intValue }
                    self.observer.eqMode.accept(preset.type)
                    self.observer.eqGains.accept(gains)
                    self.updateValue(for: .eq)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func sendMusicAction(_ action: MusicAction) {
        let commandName = CommandHelper.getCommandName(.musicControl)
        let status = presentStatus(commandName: commandName, message: "发送中…")
        let completion: (Error?) -> Void = { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                status.update(state: .failure("发送失败：\(error.localizedDescription)"))
                status.dismiss(after: 1.5)
            } else {
                status.update(state: .success("发送成功"))
                switch action {
                case .play:
                    self.observer.isPlaying.accept(true)
                case .pause:
                    self.observer.isPlaying.accept(false)
                case .next, .previous:
                    break
                }
                self.updateValue(for: .musicControl)
                status.dismiss(after: 1.0)
            }
        }
        switch action {
        case .play:
            device.commandManager.musicPlay { completion($0) }
        case .pause:
            device.commandManager.musicPause { completion($0) }
        case .next:
            device.commandManager.musicNext { completion($0) }
        case .previous:
            device.commandManager.musicPrevious { completion($0) }
        }
    }
    
    private func sendANCMode(_ mode: TSSBEarbudsAncMode) {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.ancMode), message: "发送中…")
        device.commandManager.setANC(mode: mode) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("发送失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("发送成功"))
                    self.observer.ancMode.accept(mode)
                    self.updateValue(for: .ancMode)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func presentDeviceOperationOptions() {
        if deviceKeyMappings.isEmpty && !isLoadingDeviceKeySettings {
            loadDeviceKeySettings()
        }
        let message = "请选择需要配置的按键操作"
        let alert = UIAlertController(title: "按键操作配置", message: message, preferredStyle: .actionSheet)
        deviceOperationOptions.forEach { option in
            let currentTitle = deviceKeyMappings[option.type].map { deviceFunctionName($0) } ?? "未配置"
            let actionTitle = "\(option.title)（当前：\(currentTitle)）"
            alert.addAction(UIAlertAction(title: actionTitle, style: .default) { [weak self] _ in
                self?.presentDeviceFunctionSelection(for: option.type)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        configurePopoverIfNeeded(for: alert)
        present(alert, animated: true)
    }
    
    private func presentDeviceFunctionSelection(for operation: TSSBEarbudsDeviceOperationType) {
        let title = deviceOperationName(operation)
        let currentFunction = deviceKeyMappings[operation].map { deviceFunctionName($0) } ?? "未配置"
        let alert = UIAlertController(title: title, message: "当前：\(currentFunction)\n请选择需要绑定的功能", preferredStyle: .actionSheet)
        deviceFunctionOptions.forEach { option in
            alert.addAction(UIAlertAction(title: option.title, style: .default) { [weak self] _ in
                self?.sendDeviceOperation(operation: operation, function: option.type)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        configurePopoverIfNeeded(for: alert)
        present(alert, animated: true)
    }
    
    private func sendDeviceOperation(operation: TSSBEarbudsDeviceOperationType, function: TSSBEarbudsKeyFunction) {
        let commandName = CommandHelper.getCommandName(.deviceOperation)
        let message = "\(deviceOperationName(operation)) → \(deviceFunctionName(function))"
        let status = presentStatus(commandName: commandName, message: "设置中…")
        device.commandManager.setDeviceOperation(operation: operation, function: function) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("设置失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("设置成功：\(message)"))
                    var updated = self.deviceKeyMappings
                    updated[operation] = function
                    self.deviceKeyMappings = updated
                    self.observer.keyOperationMap.accept(updated)
                    self.updateValue(for: .deviceOperation)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func presentFactoryResetConfirmation() {
        let alert = UIAlertController(
            title: "恢复出厂设置",
            message: "该操作会清除设备上的自定义配置，确定继续吗？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { [weak self] _ in
            self?.sendFactoryReset()
        })
        present(alert, animated: true)
    }
    
    private func sendFactoryReset() {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.factoryReset), message: "执行中…")
        device.commandManager.resetDevice { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("操作失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("指令已发送"))
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func presentWorkModeOptions() {
        let current = workModeDescription(observer.workMode.value)
        let alert = UIAlertController(title: "工作模式", message: "当前：\(current)", preferredStyle: .actionSheet)
        let options: [(String, TSSBEarbudsWorkMode)] = [
            ("普通模式", .normal),
            ("游戏模式", .game)
        ]
        options.forEach { name, mode in
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.sendWorkMode(mode)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        configurePopoverIfNeeded(for: alert)
        present(alert, animated: true)
    }
    
    private func sendWorkMode(_ mode: TSSBEarbudsWorkMode) {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.workMode), message: "发送中…")
        device.commandManager.setWorkMode(mode: mode) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("发送失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("发送成功"))
                    self.observer.workMode.accept(mode)
                    self.updateValue(for: .workMode)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func presentFindDeviceOptions() {
        let alert = UIAlertController(title: "查找设备", message: "请选择操作", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "开始查找", style: .default) { [weak self] _ in
            self?.sendFindDevice(start: true)
        })
        alert.addAction(UIAlertAction(title: "停止查找", style: .default) { [weak self] _ in
            self?.sendFindDevice(start: false)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        configurePopoverIfNeeded(for: alert)
        present(alert, animated: true)
    }
    
    private func sendFindDevice(start: Bool) {
        let actionText = start ? "查找" : "停止"
        let status = presentStatus(commandName: CommandHelper.getCommandName(.findDevice), message: "\(actionText)中…")
        device.commandManager.findDevice(start: start) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("操作失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("指令已发送"))
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func presentVoiceRecognitionOptions() {
        let current = observer.voiceRecognitionEnabled.value
        let message = "当前：\(current ? "已开启" : "已关闭")"
        let alert = UIAlertController(title: "语音识别设置", message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "开启", style: .default) { [weak self] _ in
            self?.sendVoiceRecognition(enabled: true)
        })
        alert.addAction(UIAlertAction(title: "关闭", style: .default) { [weak self] _ in
            self?.sendVoiceRecognition(enabled: false)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        configurePopoverIfNeeded(for: alert)
        present(alert, animated: true)
    }
    
    private func sendVoiceRecognition(enabled: Bool) {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.voiceRecognition), message: "发送中…")
        let payload: UInt8 = enabled ? 1 : 0
        device.commandManager.voiceRecognitionSetting(payload: payload) { [weak self] isSuccess, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if !isSuccess || error != nil {
                    let reason = error?.localizedDescription ?? "设备返回失败"
                    status.update(state: .failure("设置失败：\(reason)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("设置成功"))
                    self.observer.voiceRecognitionEnabled.accept(enabled)
                    self.updateValue(for: .voiceRecognition)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func queryDeviceInfo() {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.deviceInfo), message: "查询中…")
        device.commandManager.queryABMateDeviceinfo { [weak self] info, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("查询失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                    return
                }
                status.update(state: .success("查询成功"))
                if let info = info {
                    self.lastDeviceInfoSummary = "共 \(info.count) 项"
                    self.updateValue(for: .deviceInfo)
                    let preview = self.formattedDeviceInfoPreview(info)
                    let alert = UIAlertController(title: "设备信息", message: preview, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self.present(alert, animated: true)
                }
                status.dismiss(after: 1.0)
            }
        }
    }
    
    private func presentShutdownConfirmation() {
        let alert = UIAlertController(
            title: "定时关机设置",
            message: "目前仅支持立即关机操作，确认后设备将立即断电。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "立即关机", style: .destructive) { [weak self] _ in
            self?.sendShutdownDevice()
        })
        present(alert, animated: true)
    }
    
    private func sendShutdownDevice() {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.autoShutdown), message: "发送中…")
        device.commandManager.shutdownDevice { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("指令失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("指令已发送"))
                    self.recordStatus("已触发关机", for: .autoShutdown)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func presentRemoteCameraOptions() {
        let current = remoteCameraStateDescription(observer.remoteCameraState.value)
        let alert = UIAlertController(title: "远程相机控制", message: "当前：\(current)", preferredStyle: .actionSheet)
        remoteCameraOptions.forEach { option in
            alert.addAction(UIAlertAction(title: option.title, style: .default) { [weak self] _ in
                self?.sendRemoteCameraState(option.state)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        configurePopoverIfNeeded(for: alert)
        present(alert, animated: true)
    }
    
    private func sendRemoteCameraState(_ state: TSSBRemoteCameraState) {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.remoteCamera), message: "发送中…")
        device.commandManager.updateCameraState(cameraState: state) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if !success || error != nil {
                    let reason = error?.localizedDescription ?? "设备执行失败"
                    status.update(state: .failure("操作失败：\(reason)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("操作成功"))
                    self.observer.remoteCameraState.accept(state)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func presentTakePhotoOptions() {
        let message = """
请选择拍照模式：
• 高清照片（模式 0）：返回原始高质量图片
• 低分辨率 JPEG（模式 1）：返回 320×240 图像
拍照完成后，设备将通过 Notify 上报图片数据。
"""
        let alert = UIAlertController(title: "远程拍照", message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "高清照片", style: .default) { [weak self] _ in
            self?.sendTakePhoto(mode: 0)
        })
        alert.addAction(UIAlertAction(title: "320×240 JPEG", style: .default) { [weak self] _ in
            self?.sendTakePhoto(mode: 1)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        configurePopoverIfNeeded(for: alert)
        present(alert, animated: true)
    }
    
    private func sendTakePhoto(mode: UInt8) {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.startCameraAndTakephoto), message: "发送中…")
        device.commandManager.takePhoto(model: mode) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if !success || error != nil {
                    let reason = error?.localizedDescription ?? "设备执行失败"
                    status.update(state: .failure("拍照失败：\(reason)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("指令已发送"))
                    let description: String
                    switch mode {
                    case 0: description = "高清照片"
                    case 1: description = "320×240 JPEG"
                    default: description = "模式 \(mode)"
                    }
                    self.recordStatus(description, for: .startCameraAndTakephoto)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func sendStartAudioRecord() {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.startAudioRecord), message: "发送中…")
        device.commandManager.startABMateAudioRecord { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if !success || error != nil {
                    let reason = error?.localizedDescription ?? "设备执行失败"
                    status.update(state: .failure("执行失败：\(reason)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("执行成功"))
                    self.recordStatus("录音已启动", for: .startAudioRecord)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func sendShutdownRecord() {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.shutDownRecord), message: "发送中…")
        device.commandManager.shutDownABMateRecord { [weak self] code, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("执行失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("返回码 \(code)"))
                    self.recordStatus("返回码 \(code)", for: .shutDownRecord)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func sendTakeVideoRecord() {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.takeVideoRecord), message: "发送中…")
        device.commandManager.takeVideoRecord { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if !success || error != nil {
                    let reason = error?.localizedDescription ?? "设备执行失败"
                    status.update(state: .failure("执行失败：\(reason)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("执行成功"))
                    self.recordStatus("录像指令已发送", for: .takeVideoRecord)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func sendQueryStorageInfo() {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.getStorageInfo), message: "查询中…")
        queryStorageInfo { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("查询失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                    return
                }
                
                status.update(state: .success("请求已发送，等待设备上报"))
                status.dismiss(after: 1.0)
            }
        }
    }

    private func queryStorageInfo(_ completion: @escaping (Error?) -> Void) {
        let selector = NSSelectorFromString("queryABMateStorageInfoWithResult:")
        guard device.commandManager.responds(to: selector) else {
            let error = NSError(
                domain: "TSDemo.StorageQuery",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "设备不支持存储信息查询"]
            )
            completion(error)
            return
        }

        typealias Block = @convention(block) (NSError?) -> Void
        let callback: Block = { error in
            completion(error)
        }
        let blockObject = callback as AnyObject
        _ = device.commandManager.perform(selector, with: blockObject)
    }
    
    private func sendQueryMediaCount() {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.getMediaCount), message: "查询中…")
        device.commandManager.queryABMateMediaCount { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if !success || error != nil {
                    let reason = error?.localizedDescription ?? "设备执行失败"
                    status.update(state: .failure("查询失败：\(reason)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("等待设备上报"))
                    self.recordStatus("等待设备上报", for: .getMediaCount)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func presentStandardTimeOptions() {
        let alert = UIAlertController(title: "设置标准时间", message: "请选择设置方式", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "同步本机时间", style: .default) { [weak self] _ in
            self?.sendStandardTimeSync()
        })
        alert.addAction(UIAlertAction(title: "自定义输入", style: .default) { [weak self] _ in
            self?.presentCustomStandardTimeInput()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        configurePopoverIfNeeded(for: alert)
        present(alert, animated: true)
    }
    
    private func sendStandardTimeSync() {
        let now = Date()
        let timestamp = UInt32(now.timeIntervalSince1970)
        let timezoneMinutes = Int16(TimeZone.current.secondsFromGMT() / 60)
        sendStandardTime(timestamp: timestamp, timezoneMinutes: timezoneMinutes)
    }
    
    private func presentCustomStandardTimeInput() {
        let alert = UIAlertController(
            title: "自定义时间",
            message: "请输入 Unix 时间戳（秒）与时区（分钟，可选）",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "时间戳，例如 1731139200"
            textField.keyboardType = .numberPad
        }
        alert.addTextField { textField in
            textField.placeholder = "时区（分钟，可选），例如 480"
            textField.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "设置", style: .default) { [weak self] _ in
            guard let self = self else { return }
            guard
                let timestampText = alert.textFields?.first?.text,
                let timestampValue = UInt32(timestampText)
            else { return }
            let timezoneText = alert.textFields?.last?.text ?? ""
            let timezoneValue: Int16
            if let parsed = Int16(timezoneText) {
                timezoneValue = parsed
            } else {
                timezoneValue = Int16(TimeZone.current.secondsFromGMT() / 60)
            }
            self.sendStandardTime(timestamp: timestampValue, timezoneMinutes: timezoneValue)
        })
        present(alert, animated: true)
    }
    
    private func sendStandardTime(timestamp: UInt32, timezoneMinutes: Int16) {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.setStandardTime), message: "发送中…")
        device.commandManager.setABMateStandardTime(timestamp: timestamp, timezoneMinutes: timezoneMinutes) { [weak self] resultCode, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("设置失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("结果码 \(resultCode)"))
                    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
                    let formatted = self.standardTimeFormatter.string(from: date)
                    let timezoneText = self.formattedTimezone(minutes: timezoneMinutes)
                    self.lastStandardTimeSummary = "\(formatted) (UTC\(timezoneText))"
                    self.updateValue(for: .setStandardTime)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func sendFetchSubFirmwareVersion() {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.subFirmwareVersion), message: "查询中…")
        device.commandManager.getSubFirmwareVersion { [weak self] error, version in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("查询失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("查询成功"))
                    if let version = version {
                        self.observer.subFirmwareVersion.accept(version)
                    }
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func sendDeviceAuthentication() {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.deviceAuthentication), message: "发送中…")
        device.commandManager.deviceAuthentication(0x01) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("鉴权失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("鉴权成功"))
                    self.recordStatus("鉴权成功", for: .deviceAuthentication)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func sendDeviceWorkState() {
        let status = presentStatus(commandName: CommandHelper.getCommandName(.deviceWorkState), message: "查询中…")
        device.commandManager.getDeviceWorkState { [weak self] state, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    status.update(state: .failure("查询失败：\(error.localizedDescription)"))
                    status.dismiss(after: 1.5)
                } else {
                    status.update(state: .success("查询成功"))
                    self.observer.deviceWorkStateRaw.accept(state.rawValue)
                    status.dismiss(after: 1.0)
                }
            }
        }
    }
    
    private func sendUnsupportedCommand(for command: TSSBEarbudsCommand, suggestedValue: Int?) {
        let name = CommandHelper.getCommandName(command)
        let status = presentStatus(commandName: name, message: "发送中…")
        let reason = "SDK 暂未开放写入接口"
        status.update(state: .failure(reason))
        status.dismiss(after: 1.5)
        if let value = suggestedValue {
            print("ℹ️ 预期写入值 \(value) (\(name)) 未执行：\(reason)")
        }
    }
    
    private func presentUnsupportedAlert(for command: TSSBEarbudsCommand) {
        let alert = UIAlertController(
            title: CommandHelper.getCommandName(command),
            message: "暂未实现该指令的发送逻辑",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func configurePopoverIfNeeded(for alert: UIAlertController, sourceView: UIView? = nil, sourceRect: CGRect? = nil) {
        guard let popover = alert.popoverPresentationController else { return }
        guard let referenceView = sourceView ?? view else { return }
        popover.sourceView = referenceView
        if let rect = sourceRect {
            popover.sourceRect = rect
        } else {
            popover.sourceRect = CGRect(x: referenceView.bounds.midX, y: referenceView.bounds.midY, width: 0, height: 0)
        }
    }
    
    @discardableResult
    private func presentStatus(commandName: String, message: String) -> CommandStatusViewController {
        let controller = CommandStatusViewController(state: .sending("\(commandName) - \(message)"))
        present(controller, animated: true)
        return controller
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension CommandListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return supportedCommands.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CommandCell", for: indexPath)
        let command = supportedCommands[indexPath.row]
        let commandName = CommandHelper.getCommandName(command)
        let hexString = CommandHelper.hexString(for: command)
        
        var content = UIListContentConfiguration.subtitleCell()
        content.text = "\(commandName) 指令"
        if let valueText = commandValueMap[command] ?? displayValue(for: command) {
            content.secondaryText = "当前值：\(valueText) | \(hexString)"
        } else {
            content.secondaryText = hexString
        }
        cell.contentConfiguration = content
        cell.accessoryType = accessoryType(for: command)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let command = supportedCommands[indexPath.row]
        switch category.type {
        case .audio:
            handleAudioCommand(command)
        case .deviceOperation:
            handleDeviceOperationCommand(command)
        case .deviceInfo:
            handleDeviceInfoCommand(command)
        case .media:
            handleMediaCommand(command)
        case .storage:
            handleStorageCommand(command)
        case .other:
            handleOtherCommand(command)
        default:
            presentUnsupportedAlert(for: command)
        }
    }
}

