//
//  AudioDataOptionsViewController.swift
//  TSDemo
//
//  音频数据获取入口页面及占位子页面
//

import UIKit
import TopStepABMateSDK
import RxSwift

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
/// SCO链路音频数据占位页面
final class SCOAudioDataViewController: UIViewController {
    
    private let device: TSSBEarbuds
    private let observer: DeviceObserver
    
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
        showPlaceholder(text: "SCO链路音频数据功能开发中")
        print("🎧 SCO链路音频数据页面 | device: \(device)")
    }
    
    private func showPlaceholder(text: String) {
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
        ])
    }
}

/// 设备回调音频数据页面
final class DeviceCallbackAudioDataViewController: UIViewController {
    
    private enum AIRecordType: UInt8 {
        case callRecord = 0
        case aiRecord = 1
        case transRecord = 2
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
        
        startRecording(recordType: .callRecord)
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

