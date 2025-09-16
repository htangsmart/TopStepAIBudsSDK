//
//  ViewController.swift
//  TSDemo
//
//  Created by luigi on 2025/9/12.
//

import UIKit
import TopStepAIBudsSDK
import CoreBluetooth

class ViewController: UIViewController {
    private let selectButton = UIButton(type: .system)
    private let connectButton = UIButton(type: .system)
    private let selectedLabel = UILabel()

    private var selectedDevice: TSDeviceBaseInfo?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        TopStepAIBuds.logsOpen(true)

        setupUI()
    }

    private func setupUI() {
        title = "Demo"

        selectedLabel.textAlignment = .center
        selectedLabel.numberOfLines = 0
        selectedLabel.text = "No device selected"

        selectButton.setTitle("Function 1: Select Device", for: .normal)
        selectButton.addTarget(self, action: #selector(selectDeviceTapped), for: .touchUpInside)

        connectButton.setTitle("Function 2: Connect Device", for: .normal)
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)

        for v in [selectedLabel, selectButton, connectButton] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }

        NSLayoutConstraint.activate([
            selectedLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            selectedLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            selectedLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            selectButton.topAnchor.constraint(equalTo: selectedLabel.bottomAnchor, constant: 24),
            selectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            connectButton.topAnchor.constraint(equalTo: selectButton.bottomAnchor, constant: 16),
            connectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func selectDeviceTapped() {
        let vc = ScanViewController()
        vc.onSelect = { [weak self] info, _ in
            self?.selectedDevice = info
            self?.selectedLabel.text = "Selected: \(info.name)\nUUID: \(info.uuid)"
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func connectTapped() {
        guard let device = selectedDevice else {
            let alert = UIAlertController(title: "Notice", message: "Please select a device first", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        connectButton.isEnabled = false
        connectButton.setTitle("Connecting...", for: .disabled)
        
        // Connect device and set observer
        let observer: TSSoudbudObserver = self
        TopStepAIBuds.connectDevice(uuid: device.uuid, connectStyle: .BLE, category: device.deviceCategory, deviceObserver: observer) { [weak self] error, info, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.connectButton.isEnabled = true
                self.connectButton.setTitle("Function 2: Connect Device", for: .normal)

                if let error = error {
                    let alert = UIAlertController(title: "Connection Failed", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    return
                }
                if let info = info {
                    self.selectedLabel.text = "Connected: \(info.name)\nUUID: \(info.uuid)"
                }
            }
        }
    }
    
    
    // When device is connected successfully, you can call related commands to get/set device information
    func sendCommand() {
        
        let currentConnectedDevice = TopStepAIBuds.shared.earbuds
        let command = currentConnectedDevice?.commandManager
        command?.getDevicePower { error, result in
            
            if let error = error {
            
                print("getDevicePower fail, reason: \(error.localizedDescription)")
                return
            }
            
            print("devicePower: \(String(describing: result))")
        }
    }
    
    
    
}

// Listen to device callback data
extension ViewController: TSSoudbudObserver {
    func observerPowerChange(leftPower: NSNumber?, leftCharging: NSNumber?, rightPower: NSNumber?, rightCharging: NSNumber?, hubPower: NSNumber?, hubCharging: NSNumber?) {
        print("[Observer] PowerChange - L: \(String(describing: leftPower)) (charging: \(String(describing: leftCharging))) | R: \(String(describing: rightPower)) (charging: \(String(describing: rightCharging))) | Hub: \(String(describing: hubPower)) (charging: \(String(describing: hubCharging)))")
    }
    
    func observerEQSettingChange(mode: UInt8, gains: [NSNumber]) {
        print("[Observer] EQSettingChange - mode: \(mode), gains: \(gains)")
    }
    
    func observerMultipointInfoChange(devices: [NSDictionary]) {
        print("[Observer] MultipointInfoChange - devices: \(devices)")
    }
    
    func observerKeySettingsChange(operations: [NSNumber], functions: [NSNumber]) {
        print("[Observer] KeySettingsChange - operations: \(operations), functions: \(functions)")
    }
    
    func observerPlayStateChange(isPlaying: Bool) {
        print("[Observer] PlayStateChange - isPlaying: \(isPlaying)")
    }
    
    func observerWorkModeChange(workMode: TopStepAIBudsSDK.TSSBEarbudsWorkMode) {
        print("[Observer] WorkModeChange - mode: \(workMode.rawValue)")
    }
    
    func observerInEarStatusChange(leftInEar: Bool, rightInEar: Bool) {
        print("[Observer] InEarStatusChange - left: \(leftInEar), right: \(rightInEar)")
    }
    
    func observerTWSConnectedChange(isConnected: Bool) {
        print("[Observer] TWSConnectedChange - isConnected: \(isConnected)")
    }
    
    func observerDeviceVolumeChange(volume: UInt8) {
        print("[Observer] DeviceVolumeChange - volume: \(volume)")
    }
    
    func observerANCModeChange(mode: TopStepAIBudsSDK.TSSBEarbudsAncMode) {
        print("[Observer] ANCModeChange - mode: \(mode.rawValue)")
    }
    
    func observerANCGainChange(gain: UInt8) {
        print("[Observer] ANCGainChange - gain: \(gain)")
    }
    
    func observerTransparencyGainChange(gain: UInt8) {
        print("[Observer] TransparencyGainChange - gain: \(gain)")
    }
    
    func observerSoundEffect3DChange(isEnabled: Bool) {
        print("[Observer] SoundEffect3DChange - isEnabled: \(isEnabled)")
    }
    
    func observerBassEngineStatusChange(isEnabled: Bool) {
        print("[Observer] BassEngineStatusChange - isEnabled: \(isEnabled)")
    }
        
    func observerPromptToneTypeChange(type: UInt8) {
        print("[Observer] PromptToneTypeChange - type: \(type)")
    }
    
    func observerLEDSwitchChange(isOn: Bool) {
        print("[Observer] LEDSwitchChange - isOn: \(isOn)")
    }
    
    func observerMainSideChange(isLeft: Bool) {
        print("[Observer] MainSideChange - isLeft: \(isLeft)")
    }
    
    func observerMultipointStatusChange(isEnabled: Bool) {
        print("[Observer] MultipointStatusChange - isEnabled: \(isEnabled)")
    }
        
    func observerVoiceRecognitionChange(isEnabled: Bool) {
        print("[Observer] VoiceRecognitionChange - isEnabled: \(isEnabled)")
    }
    
    func observerRemoteCameraControlState(state: UInt8) {
        print("[Observer] RemoteCameraControlState - state: \(state)")
    }
    
    func observerMediaCountDidChanged(picCount: UInt32, videoCount: UInt32, audioCount: UInt32) {
        print("[Observer] MediaCountChanged - pic: \(picCount), video: \(videoCount), audio: \(audioCount)")
    }
    
    func observerWifiStateChanged(state: TopStepAIBudsSDK.TSSBEarbudsWiFiState) {
        print("[Observer] WiFiStateChanged - state: \(state.rawValue)")
    }
    
    func observerWifiAddressNotify(wifiAddress: String) {
        print("[Observer] WiFiAddressNotify - address: \(wifiAddress)")
    }
    
    func observerAIRecordNotify(recordData: Data?) {
        let length = recordData?.count ?? 0
        print("[Observer] AIRecordNotify - dataLength: \(length)")
    }
    
    func observerAIStateNotify(status: Data) {
        print("[Observer] AIStateNotify - dataLength: \(status.count)")
    }
    
    func observerIsSupportCallRecordNotify(status: Bool) {
        print("[Observer] IsSupportCallRecordNotify - status: \(status)")
    }
    
    func observerAIChatImageNotify(imageData: Data) {
        print("[Observer] AIChatImageNotify - dataLength: \(imageData.count)")
    }
    
    func observerSubFirmwareVersionNotify(version: String) {
        print("[Observer] SubFirmwareVersionNotify - version: \(version)")
    }
    
    func observerDeviceBTState(state: TopStepAIBudsSDK.TSBTConnectState, peripheral: CBPeripheral) {
        print("[Observer] DeviceBTState - state: \(state) | peripheral: \(peripheral.identifier.uuidString)")
    }
    
    
}
