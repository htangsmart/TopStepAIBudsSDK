//
//  AudioDataOptionsViewController.swift
//  TSDemo
//
//  音频数据获取入口页面及占位子页面
//

import UIKit
import TopStepABMateSDK
import RxSwift
import RxRelay

/// 音频数据获取列表页面
final class AudioDataOptionsViewController: UIViewController {
    
    // MARK: - Types
    private struct OptionItem {
        let title: String
        let subtitle: String
        let action: () -> Void
    }
    
    // MARK: - Properties
    private let device: TSSBEarbuds
    private let observer: DeviceObserver
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var items: [OptionItem] = []
    
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
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "音频数据获取"
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AudioOptionCell")
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
            OptionItem(title: "SCO链路音频数据", subtitle: "通过SCO链路实时获取音频") { [weak self] in
                guard let self = self else { return }
                let vc = SCOAudioDataViewController(device: self.device, observer: self.observer)
                self.navigationController?.pushViewController(vc, animated: true)
            },
            OptionItem(title: "设备回调音频数据", subtitle: "监听设备回调的音频片段") { [weak self] in
                guard let self = self else { return }
                let vc = DeviceCallbackAudioDataViewController(device: self.device, observer: self.observer)
                self.navigationController?.pushViewController(vc, animated: true)
            }
        ]
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension AudioDataOptionsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AudioOptionCell", for: indexPath)
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
        items[indexPath.row].action()
    }
}

// MARK: - 占位页面
/// SCO链路音频数据页面
final class SCOAudioDataViewController: UIViewController {
    
    private let device: TSSBEarbuds
    private let observer: DeviceObserver
    private let captureManager = TSSCOAudioCaptureManager()
    private let disposeBag = DisposeBag()
    
    private lazy var scoStatusLabel: UILabel = makeStatusLabel()
    private lazy var bluetoothStatusLabel: UILabel = makeStatusLabel()
    private lazy var vadStatusLabel: UILabel = makeStatusLabel()
    private lazy var dataCountLabel: UILabel = makeStatusLabel()
    private lazy var fileStatusLabel: UILabel = makeStatusLabel()
    private lazy var vadSwitchLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.numberOfLines = 1
        label.text = "启用语音活动检测 (VAD)"
        return label
    }()
    private lazy var vadSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.addTarget(self, action: #selector(vadSwitchValueChanged(_:)), for: .valueChanged)
        return uiSwitch
    }()
    private lazy var startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("开启SCO链路", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        return button
    }()
    private lazy var stopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("关闭SCO链路", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.isEnabled = false
        button.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
        return button
    }()
    private lazy var logTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .secondaryLabel
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return textView
    }()
    
    private var currentTempFilePath: String?
    private var lastSavedFileURL: URL?
    private var totalBytesInCurrentSegment: Int = 0
    private var totalFramesInCurrentSegment: Int = 0
    private var isVoiceSegmentActive: Bool = false
    private let sampleRate = 16_000
    private let channelCount = 1
    private lazy var logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    private lazy var fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    
    init(device: TSSBEarbuds, observer: DeviceObserver) {
        self.device = device
        self.observer = observer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "SCO链路音频数据"
        setupUI()
        bindObserver()
        setupCaptureCallbacks()
        updateAllStatusLabels()
        vadSwitch.isOn = captureManager.voiceActivityDetectionEnabled
        appendLog("页面初始化完成，等待操作")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            tearDownCaptureIfNeeded()
        }
    }
    
    deinit {
        tearDownCaptureIfNeeded()
    }
    
    // MARK: - UI
    private func setupUI() {
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        let vadSwitchRow = UIStackView(arrangedSubviews: [vadSwitchLabel, vadSwitch])
        vadSwitchRow.axis = .horizontal
        vadSwitchRow.alignment = .center
        vadSwitchRow.spacing = 12
        
        let buttonStack = UIStackView(arrangedSubviews: [startButton, stopButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        
        logTextView.translatesAutoresizingMaskIntoConstraints = false
        logTextView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        
        contentStack.addArrangedSubview(scoStatusLabel)
        contentStack.addArrangedSubview(bluetoothStatusLabel)
        contentStack.addArrangedSubview(vadStatusLabel)
        contentStack.addArrangedSubview(dataCountLabel)
        contentStack.addArrangedSubview(fileStatusLabel)
        contentStack.addArrangedSubview(vadSwitchRow)
        contentStack.addArrangedSubview(buttonStack)
        contentStack.addArrangedSubview(logTextView)
        
        view.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - Binding
    private func bindObserver() {
        observer.btConnectState
            .asObservable()
            .compactMap { $0 }
            .distinctUntilChanged { $0.rawValue == $1.rawValue }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                self?.bluetoothStatusLabel.text = "蓝牙连接状态：\(self?.describe(btState: state) ?? "未知")"
            })
            .disposed(by: disposeBag)
    }
    
    private func setupCaptureCallbacks() {
        captureManager.setupSpeakStart({ [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                guard !self.isVoiceSegmentActive else {
                    self.appendLog("检测到语音开始（忽略重复回调）")
                    return
                }
                self.isVoiceSegmentActive = true
                self.currentTempFilePath = self.captureManager.fileManager.getCurrentTempAudioFilePath()
                self.totalBytesInCurrentSegment = 0
                self.totalFramesInCurrentSegment = 0
                self.updateVADStatusLabel(with: .speakingStar)
                self.updateDataCountLabel()
                self.appendLog("检测到语音开始")
            }
        }, data: { [weak self] data in
            guard let self else { return }
            DispatchQueue.main.async {
                self.totalBytesInCurrentSegment += data.count
                self.totalFramesInCurrentSegment += data.count / MemoryLayout<Int16>.size
                self.updateDataCountLabel()
            }
        }, speakEnd: { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.appendLog("检测到语音结束")
                self.updateVADStatusLabel(with: .speakingEnd)
                self.handleSpeechSegmentFinished()
            }
        })
    }
    
    private func tearDownCaptureIfNeeded() {
        if captureManager.isCapturing {
            captureManager.stopCapture()
            appendLog("页面离开，自动关闭SCO链路")
        }
    }
    
    // MARK: - Actions
    @objc private func startButtonTapped() {
        guard !captureManager.isCapturing else {
            appendLog("SCO链路已经开启")
            return
        }
        appendLog("正在开启SCO链路…")
        updateButtonStates(isCapturing: true, temporarilyDisable: true)
        captureManager.startCapturePreferBluetooth(true, sampleRate: Double(sampleRate), success: { [weak self] in
            DispatchQueue.main.async {
                self?.appendLog("SCO链路开启成功")
                self?.updateButtonStates(isCapturing: true)
                self?.updateAllStatusLabels()
            }
        }, failed: { [weak self] error in
            DispatchQueue.main.async {
                self?.appendLog("SCO链路开启失败：\(error.localizedDescription)")
                self?.updateButtonStates(isCapturing: false)
                self?.updateAllStatusLabels()
            }
        })
    }
    
    @objc private func stopButtonTapped() {
        guard captureManager.isCapturing else {
            appendLog("SCO链路已关闭")
            return
        }
        
        // 如果当前正在说话，先保存当前数据
        if isVoiceSegmentActive {
            appendLog("检测到正在说话，先保存当前数据…")
            saveCurrentSpeechSegment()
        }
        
        appendLog("正在关闭SCO链路…")
        captureManager.stopCapture()
        updateButtonStates(isCapturing: false)
        updateAllStatusLabels()
        appendLog("SCO链路已关闭")
        isVoiceSegmentActive = false
    }
    
    @objc private func vadSwitchValueChanged(_ sender: UISwitch) {
        captureManager.voiceActivityDetectionEnabled = sender.isOn
        appendLog("VAD已\(sender.isOn ? "开启" : "关闭")")
        updateVADStatusLabel(with: captureManager.voiceActivityDetectionEnabled ? captureManager.vadState : nil)
    }
    
    // MARK: - Status Updates
    private func updateAllStatusLabels() {
        updateSCOStatusLabel()
        bluetoothStatusLabel.text = "蓝牙连接状态：\(describe(btState: observer.btConnectState.value ?? .disconnected))"
        updateVADStatusLabel(with: captureManager.voiceActivityDetectionEnabled ? captureManager.vadState : nil)
        updateDataCountLabel()
        updateFileStatusLabel()
    }
    
    private func updateSCOStatusLabel() {
        let status = captureManager.isCapturing ? "已开启" : "未开启"
        scoStatusLabel.text = "SCO链路状态：\(status)"
    }
    
    private func updateVADStatusLabel(with state: TSVADState?) {
        guard captureManager.voiceActivityDetectionEnabled else {
            vadStatusLabel.text = "VAD状态：未启用"
            return
        }
        let currentState = state ?? captureManager.vadState
        vadStatusLabel.text = "VAD状态：\(describe(vadState: currentState))"
    }
    
    private func updateDataCountLabel() {
        let kiloBytes = Double(totalBytesInCurrentSegment) / 1024.0
        dataCountLabel.text = String(format: "当前片段：%d 帧 / %.2f KB", totalFramesInCurrentSegment, kiloBytes)
    }
    
    private func updateFileStatusLabel() {
        if let url = lastSavedFileURL {
            fileStatusLabel.text = "最近文件：\(url.lastPathComponent)"
        } else {
            fileStatusLabel.text = "最近文件：--"
        }
    }
    
    private func updateButtonStates(isCapturing: Bool, temporarilyDisable: Bool = false) {
        if temporarilyDisable {
            startButton.isEnabled = false
            stopButton.isEnabled = false
            return
        }
        startButton.isEnabled = !isCapturing
        stopButton.isEnabled = isCapturing
    }
    
    // MARK: - Speech Segment Handling
    private func handleSpeechSegmentFinished() {
        guard isVoiceSegmentActive else {
            appendLog("检测到语音结束，但当前未标记语音段，忽略")
            return
        }
        isVoiceSegmentActive = false
        saveCurrentSpeechSegment()
    }
    
    /// 保存当前语音段数据（用于正常结束或强制保存）
    private func saveCurrentSpeechSegment() {
        let frames = totalFramesInCurrentSegment
        let bytes = totalBytesInCurrentSegment
        totalFramesInCurrentSegment = 0
        totalBytesInCurrentSegment = 0
        updateDataCountLabel()
        
        guard captureManager.voiceActivityDetectionEnabled else {
            appendLog("VAD已关闭，跳过转码缓存文件")
            removeCurrentTempFileIfNeeded()
            return
        }
        
        guard let tempPath = captureManager.fileManager.getCurrentTempAudioFilePath() ?? currentTempFilePath else {
            appendLog("未找到缓存PCM文件路径")
            return
        }
        currentTempFilePath = nil
        let tempURL = URL(fileURLWithPath: tempPath)
        appendLog("准备转码缓存文件（\(frames) 帧，\(bytes) 字节）")
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.convertTempPCMToWav(tempURL: tempURL, frameCount: frames)
        }
    }
    
    private func removeCurrentTempFileIfNeeded() {
        guard let tempPath = captureManager.fileManager.getCurrentTempAudioFilePath() ?? currentTempFilePath else {
            return
        }
        currentTempFilePath = nil
        let tempURL = URL(fileURLWithPath: tempPath)
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
            appendLog("已删除临时PCM文件：\(tempURL.lastPathComponent)")
        }
    }
    
    private func convertTempPCMToWav(tempURL: URL, frameCount: Int) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: tempURL.path) else {
            DispatchQueue.main.async { [weak self] in
                self?.appendLog("临时PCM文件不存在，转码取消")
            }
            return
        }
        
        do {
            let pcmData = try Data(contentsOf: tempURL)
            guard !pcmData.isEmpty else {
                try? fileManager.removeItem(at: tempURL)
                DispatchQueue.main.async { [weak self] in
                    self?.appendLog("PCM数据为空，已删除缓存文件")
                }
                return
            }
            
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let recordDirectory = documentsURL.appendingPathComponent("AIChatRecord", isDirectory: true)
            if !fileManager.fileExists(atPath: recordDirectory.path) {
                try fileManager.createDirectory(at: recordDirectory, withIntermediateDirectories: true)
            }
            
            let baseName = fileNameDateFormatter.string(from: Date())
            var destinationURL = recordDirectory.appendingPathComponent(baseName).appendingPathExtension("wav")
            var index = 1
            while fileManager.fileExists(atPath: destinationURL.path) {
                destinationURL = recordDirectory.appendingPathComponent("\(baseName)_\(index)").appendingPathExtension("wav")
                index += 1
            }
            
            var wavData = makeWavHeader(dataLength: pcmData.count)
            wavData.append(pcmData)
            try wavData.write(to: destinationURL, options: .atomic)
            try? fileManager.removeItem(at: tempURL)
            
            DispatchQueue.main.async { [weak self] in
                self?.lastSavedFileURL = destinationURL
                self?.appendLog("已保存WAV文件：\(destinationURL.lastPathComponent)（\(frameCount) 帧）")
                self?.updateFileStatusLabel()
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.appendLog("转码失败：\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helpers
    private func appendLog(_ message: String) {
        let timestamp = logDateFormatter.string(from: Date())
        let newLine = "[\(timestamp)] \(message)"
        let existing = logTextView.text ?? ""
        let combined = existing.isEmpty ? newLine : existing + "\n" + newLine
        let trimmed = combined.suffix(10_000)
        logTextView.text = String(trimmed)
        if logTextView.text.count > 0 {
            logTextView.scrollRangeToVisible(NSRange(location: logTextView.text.count - 1, length: 1))
        }
    }
    
    private func makeWavHeader(dataLength: Int) -> Data {
        let bitsPerSample: UInt16 = 16
        let blockAlign = UInt16(channelCount) * bitsPerSample / 8
        let byteRate = UInt32(sampleRate) * UInt32(blockAlign)
        let chunkSize = UInt32(36 + dataLength)
        
        var header = Data(capacity: 44)
        header.append(contentsOf: "RIFF".utf8)
        header.append(littleEndian: chunkSize)
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(littleEndian: UInt32(16))
        header.append(littleEndian: UInt16(1))
        header.append(littleEndian: UInt16(channelCount))
        header.append(littleEndian: UInt32(sampleRate))
        header.append(littleEndian: byteRate)
        header.append(littleEndian: blockAlign)
        header.append(littleEndian: bitsPerSample)
        header.append(contentsOf: "data".utf8)
        header.append(littleEndian: UInt32(dataLength))
        return header
    }
    
    private func describe(vadState: TSVADState) -> String {
        switch vadState {
        case .silence:
            return "静音"
        case .speakingStar:
            return "开始说话"
        case .speaking:
            return "说话中"
        case .speakingEnd:
            return "结束说话"
        @unknown default:
            return "未知"
        }
    }
    
    private func describe(btState: TSBTConnectState) -> String {
        switch btState {
        case .connected:
            return "已连接"
        case .connecting:
            return "连接中"
        case .disconnecting:
            return "断开中"
        case .disconnected:
            return "未连接"
        @unknown default:
            return "未知"
        }
    }
    
    private func makeStatusLabel() -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }
}

/// 设备回调音频数据页面
final class DeviceCallbackAudioDataViewController: UIViewController {
    
    private enum AIRecordType: UInt8 {
        case aiRecord = 0       // 现场录音
        case callRecord = 1     // 通话录音
        case transRecord = 2    // 翻译录音
    }
    
    private let device: TSSBEarbuds
    private let observer: DeviceObserver
    private let disposeBag = DisposeBag()
    
    private let recordingStateLabel = UILabel()
    private let timerLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    
    private let sampleRate = 16_000
    private let channelCount = 1
    
    private var isRecording = false {
        didSet { updateRecordingStateLabel() }
    }
    private var recordingStartDate: Date?
    private var recordingTimer: Timer?
    private var currentRecordFileHandle: FileHandle?
    private var currentRecordFileURL: URL?
    private var currentRecordType: AIRecordType?
    private let audioWriteQueue = DispatchQueue(label: "com.tsdemo.aiRecord.write")
    private var opusDecoder: TSOpusDecoder?
    private var opusFrameBuffer = Data()
    private var totalPCMBytes: Int = 0
    
    init(device: TSSBEarbuds, observer: DeviceObserver) {
        self.device = device
        self.observer = observer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "设备回调音频数据"
        setupUI()
        bindObserver()
        updateRecordingStateLabel()
        updateTimerLabel()
        updateButtonStates()
        print("🎧 设备回调音频数据页面 | device: \(device)")
    }
    
    deinit {
        recordingTimer?.invalidate()
        closeCurrentFile()
    }
    
    // MARK: - Setup
    private func setupUI() {
        recordingStateLabel.font = .preferredFont(forTextStyle: .headline)
        recordingStateLabel.textColor = .label
        recordingStateLabel.numberOfLines = 1
        
        timerLabel.font = .preferredFont(forTextStyle: .title3)
        timerLabel.textColor = .secondaryLabel
        timerLabel.numberOfLines = 1
        
        startButton.setTitle("开始录音", for: .normal)
        startButton.addTarget(self, action: #selector(startRecordingTapped), for: .touchUpInside)
        
        stopButton.setTitle("停止录音", for: .normal)
        stopButton.addTarget(self, action: #selector(stopRecordingTapped), for: .touchUpInside)
        
        let buttonStack = UIStackView(arrangedSubviews: [startButton, stopButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        
        let mainStack = UIStackView(arrangedSubviews: [
            recordingStateLabel,
            timerLabel,
            buttonStack
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 20
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func bindObserver() {
        observer.aiRecordData
            .subscribe(onNext: { [weak self] data in
                self?.handleIncomingAudioData(data)
            })
            .disposed(by: disposeBag)
    }
    
    @objc private func startRecordingTapped() {
        guard !isRecording else {
            showAlert(title: "提示", message: "当前正在录音，请先停止。")
            return
        }
        
        startRecording(recordType: .aiRecord)
    }
    
    @objc private func stopRecordingTapped() {
        guard isRecording else {
            showAlert(title: "提示", message: "当前未开启录音。")
            return
        }
        stopRecordingFlow()
    }
    
    // MARK: - Recording Flow
    private func startRecording(recordType: AIRecordType) {
        device.commandManager.controlABMetaRecord(recordType: recordType.rawValue, status: 1) { [weak self] isSuccess, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    self.showAlert(title: "录音启动失败", message: error.localizedDescription)
                    return
                }
                guard isSuccess else {
                    self.showAlert(title: "录音启动失败", message: "设备返回失败。")
                    return
                }
                
                do {
                    guard let decoder = TSOpusDecoder(sampleRate: Int32(self.sampleRate), channels: Int32(self.channelCount)) as TSOpusDecoder? else {
                        self.showAlert(title: "录音启动失败", message: "Opus 解码器初始化失败")
                        return
                    }
                    let fileURL = try self.prepareRecordFile()
                    self.currentRecordFileURL = fileURL
                    self.currentRecordFileHandle = try FileHandle(forWritingTo: fileURL)
                    if #available(iOS 13.0, *) {
                        try self.currentRecordFileHandle?.seekToEnd()
                    } else {
                        self.currentRecordFileHandle?.seekToEndOfFile()
                    }
                    self.currentRecordType = recordType
                    self.isRecording = true
                    self.opusDecoder = decoder
                    self.totalPCMBytes = 0
                    self.opusFrameBuffer.removeAll(keepingCapacity: true)
                    self.recordingStartDate = Date()
                    self.startTimer()
                    self.updateButtonStates()
                    self.showAlert(title: "录音已开始", message: "当前录音类型：\(self.describe(recordType: recordType))")
                } catch {
                    self.opusDecoder?.close()
                    self.opusDecoder = nil
                    self.showAlert(title: "创建文件失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func stopRecordingFlow() {
        guard let recordType = currentRecordType else {
            resetRecordingState()
            return
        }
        
        device.commandManager.controlABMetaRecord(recordType: recordType.rawValue, status: 0) { [weak self] isSuccess, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    self.showAlert(title: "停止录音失败", message: error.localizedDescription)
                    return
                }
                guard isSuccess else {
                    self.showAlert(title: "停止录音失败", message: "设备返回失败。")
                    return
                }
                self.finalizeWavFile()
                let fileURL = self.currentRecordFileURL
                self.resetRecordingState()
                if let fileURL = fileURL {
                    self.showAlert(title: "录音完成", message: "录音文件已保存至：\n\(fileURL.path)")
                } else {
                    self.showAlert(title: "录音完成", message: "录音文件已保存。")
                }
            }
        }
    }
    
    private func handleIncomingAudioData(_ data: Data) {
        guard isRecording, !data.isEmpty, let decoder = opusDecoder else { return }
        audioWriteQueue.async { [weak self] in
            guard let self, let handle = self.currentRecordFileHandle else { return }
            self.opusFrameBuffer.append(data)
            let frameSize = 80
            while self.opusFrameBuffer.count >= frameSize {
                let frame = self.opusFrameBuffer.prefix(frameSize)
                self.opusFrameBuffer.removeFirst(frameSize)
                guard let pcmData = decoder.decodePacket(frame) else {
                    print("❌ 解码 Opus 失败，忽略该帧")
                    continue
                }
                do {
                    if #available(iOS 13.0, *) {
                        try handle.write(contentsOf: pcmData)
                    } else {
                        handle.write(pcmData)
                    }
                    self.totalPCMBytes += pcmData.count
                } catch {
                    print("❌ 写入录音数据失败: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func prepareRecordFile() throws -> URL {
        let fm = FileManager.default
        let documentURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folderURL = documentURL.appendingPathComponent("AIRecord", isDirectory: true)
        if !fm.fileExists(atPath: folderURL.path) {
            try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = formatter.string(from: Date()) + ".wav"
        let fileURL = folderURL.appendingPathComponent(fileName)
        if fm.fileExists(atPath: fileURL.path) {
            try fm.removeItem(at: fileURL)
        }
        let header = makeWavHeader(dataLength: 0)
        guard fm.createFile(atPath: fileURL.path, contents: header) else {
            throw NSError(domain: "TSDemo.Audio", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建录音文件"])
        }
        return fileURL
    }
    
    private func startTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            self?.updateTimerLabel()
        })
        RunLoop.main.add(recordingTimer!, forMode: .common)
        updateTimerLabel()
    }
    
    private func resetRecordingState() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartDate = nil
        isRecording = false
        opusDecoder?.close()
        opusDecoder = nil
        opusFrameBuffer.removeAll(keepingCapacity: false)
        closeCurrentFile()
        currentRecordType = nil
        totalPCMBytes = 0
        updateTimerLabel()
        updateButtonStates()
    }
    
    private func closeCurrentFile() {
        audioWriteQueue.sync {
            if let handle = self.currentRecordFileHandle {
                if #available(iOS 13.0, *) {
                    try? handle.close()
                } else {
                    handle.closeFile()
                }
            }
            self.currentRecordFileHandle = nil
        }
        currentRecordFileURL = nil
    }
    
    private func finalizeWavFile() {
        audioWriteQueue.sync {
            guard let handle = self.currentRecordFileHandle else { return }
            let header = self.makeWavHeader(dataLength: UInt32(self.totalPCMBytes))
            if #available(iOS 13.0, *) {
                try? handle.seek(toOffset: 0)
                handle.write(header)
            } else {
                handle.seek(toFileOffset: 0)
                handle.write(header)
            }
        }
    }
    
    private func updateRecordingStateLabel() {
        recordingStateLabel.text = "录音状态：\(isRecording ? "录音中" : "未录音")"
    }
    
    private func updateTimerLabel() {
        let elapsed = recordingStartDate.map { Date().timeIntervalSince($0) } ?? 0
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        timerLabel.text = String(format: "录音时长：%02d:%02d", minutes, seconds)
    }
    
    private func updateButtonStates() {
        startButton.isEnabled = !isRecording
        stopButton.isEnabled = isRecording
    }
    
    private func describe(recordType: AIRecordType) -> String {
        switch recordType {
        case .callRecord:
            return "通话录音"
        case .aiRecord:
            return "现场录音"
        case .transRecord:
            return "翻译录音"
        @unknown default:
            return "未知类型"
        }
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确认", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    private func makeWavHeader(dataLength: UInt32) -> Data {
        let bitsPerSample: UInt16 = 16
        let blockAlign = UInt16(channelCount) * bitsPerSample / 8
        let byteRate = UInt32(sampleRate) * UInt32(blockAlign)
        let chunkSize = UInt32(36) + dataLength
        
        var data = Data(capacity: 44)
        data.append(contentsOf: "RIFF".utf8)
        data.append(littleEndian: chunkSize)
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(littleEndian: UInt32(16)) // PCM header size
        data.append(littleEndian: UInt16(1)) // PCM format
        data.append(littleEndian: UInt16(channelCount))
        data.append(littleEndian: UInt32(sampleRate))
        data.append(littleEndian: byteRate)
        data.append(littleEndian: blockAlign)
        data.append(littleEndian: bitsPerSample)
        data.append(contentsOf: "data".utf8)
        data.append(littleEndian: dataLength)
        return data
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append($0.bindMemory(to: UInt8.self)) }
    }
}

