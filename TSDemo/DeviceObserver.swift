//
//  DeviceObserver.swift
//  TSDemo
//
//  设备数据监听器 - Device Data Observer
//  继承 TSSoudbudObserver，使用 RxSwift 实现响应式数据绑定
//  Inherits TSSoudbudObserver, implements reactive data binding using RxSwift
//

import Foundation
import RxSwift
import RxRelay
import TopStepABMateSDK
import CoreBluetooth

/// 设备数据监听器类
/// Device data observer class that implements TSSoudbudObserver protocol
/// 使用 RxSwift BehaviorRelay 存储设备状态，支持响应式数据绑定
/// Uses RxSwift BehaviorRelay to store device state, supports reactive data binding
class DeviceObserver: NSObject, TSSoudbudObserver {
    
    // MARK: - RxSwift Properties (Power & Charging)
    /// 左耳电量 (0-100) - Left earbud battery (0-100)
    let leftPower = BehaviorRelay<Int>(value: 0)
    
    /// 右耳电量 (0-100) - Right earbud battery (0-100)
    let rightPower = BehaviorRelay<Int>(value: 0)
    
    /// 充电仓电量 (0-100) - Charging case battery (0-100)
    let hubPower = BehaviorRelay<Int>(value: 0)
    
    /// 左耳是否充电中 - Left earbud charging status
    let leftCharging = BehaviorRelay<Bool>(value: false)
    
    /// 右耳是否充电中 - Right earbud charging status
    let rightCharging = BehaviorRelay<Bool>(value: false)
    
    /// 充电仓是否充电中 - Charging case charging status
    let hubCharging = BehaviorRelay<Bool>(value: false)
    
    // MARK: - RxSwift Properties (Device Status)
    /// 固件版本号 - Firmware version
    let firmwareVersion = BehaviorRelay<String>(value: "未知")
    
    /// 子固件版本号 - Sub firmware version
    let subFirmwareVersion = BehaviorRelay<String>(value: "未知")
    
    /// 连接状态描述 - Connection state description
    let connectionState = BehaviorRelay<String>(value: "未连接")
    
    /// 蓝牙连接状态 - Bluetooth connection state
    let btConnectState = BehaviorRelay<TSBTConnectState?>(value: nil)
    
    /// 工作模式 - Work mode
    let workMode = BehaviorRelay<TSSBEarbudsWorkMode>(value: .normal)
    
    /// 播放状态 - Playback state
    let isPlaying = BehaviorRelay<Bool>(value: false)
    
    /// 左耳入耳状态 - Left earbud in-ear status
    let leftInEar = BehaviorRelay<Bool>(value: false)
    
    /// 右耳入耳状态 - Right earbud in-ear status
    let rightInEar = BehaviorRelay<Bool>(value: false)
    
    /// TWS 连接状态 - TWS connection status
    let twsConnected = BehaviorRelay<Bool>(value: false)
    
    /// 设备音量 (0-100) - Device volume (0-100)
    let deviceVolume = BehaviorRelay<Int>(value: 0)
    
    // MARK: - RxSwift Properties (ANC & Audio)
    /// ANC 模式 - ANC mode
    let ancMode = BehaviorRelay<TSSBEarbudsAncMode>(value: .normal)
    
    /// ANC 增益 - ANC gain
    let ancGain = BehaviorRelay<Int>(value: 0)
    
    /// 透传增益 - Transparency gain
    let transparencyGain = BehaviorRelay<Int>(value: 0)
    
    /// 3D 音效开关 - 3D sound effect switch
    let soundEffect3DEnabled = BehaviorRelay<Bool>(value: false)
    
    /// 低音引擎开关 - Bass engine switch
    let bassEngineEnabled = BehaviorRelay<Bool>(value: false)
    
    // MARK: - RxSwift Properties (Settings)
    /// EQ 模式 - EQ mode
    let eqMode = BehaviorRelay<Int>(value: 0)
    
    /// EQ 增益数组 - EQ gains array
    let eqGains = BehaviorRelay<[Int]>(value: [])
    
    /// LED 开关 - LED switch
    let ledEnabled = BehaviorRelay<Bool>(value: false)
    
    /// 主侧（左/右） - Main side (left/right)
    let isLeftMain = BehaviorRelay<Bool>(value: true)
    
    /// 多点连接状态 - Multipoint connection status
    let multipointEnabled = BehaviorRelay<Bool>(value: false)
    
    /// 语音识别开关 - Voice recognition switch
    let voiceRecognitionEnabled = BehaviorRelay<Bool>(value: false)
    
    /// 按键操作映射 - Key operation mapping
    let keyOperationMap = BehaviorRelay<[TSSBEarbudsDeviceOperationType: TSSBEarbudsKeyFunction]>(value: [:])
    
    /// 提示音类型 - Prompt tone type
    let promptToneType = BehaviorRelay<UInt8?>(value: nil)
    
    /// 远程相机状态 - Remote camera state
    let remoteCameraState = BehaviorRelay<TSSBRemoteCameraState?>(value: nil)
    
    /// 存储空间信息（已用/剩余，单位 MB）
    let storageSpace = BehaviorRelay<(used: UInt32, free: UInt32)?>(value: nil)
    
    /// 媒体文件数量统计
    let mediaCount = BehaviorRelay<(pic: UInt32, video: UInt32, audio: UInt32)?>(value: nil)
    
    /// 设备工作状态原始值
    let deviceWorkStateRaw = BehaviorRelay<UInt8?>(value: nil)
    
    // MARK: - RxSwift Properties (WiFi & AI)
    /// WiFi 状态 - WiFi state
    let wifiState = BehaviorRelay<TSSBEarbudsWiFiState?>(value: nil)
    
    /// WiFi 地址 - WiFi address
    let wifiAddress = BehaviorRelay<String>(value: "")
    
    /// 是否支持通话录音 - Support call recording
    let supportCallRecord = BehaviorRelay<Bool>(value: false)
    
    /// 设备支持功能 - Device support function
    let supportFunction = BehaviorRelay<DeviceSupportFunction>(value: DeviceSupportFunction())
    
    // MARK: - Initialization
    override init() {
        super.init()
        print("📱 DeviceObserver 初始化 - DeviceObserver initialized")
    }
    
    deinit {
        print("📱 DeviceObserver 释放 - DeviceObserver deallocated")
    }
}

// MARK: - TSBTObserver Protocol Implementation
extension DeviceObserver {
    
    /// 更新设备蓝牙连接状态（从连接回调中调用）
    /// Update device Bluetooth connection state (called from connection callback)
    /// - Parameters:
    ///   - state: 连接状态 - Connection state
    ///   - peripheral: 外设对象 - Peripheral object
    func updateConnectionState(state: TSBTConnectState, peripheral: CBPeripheral?) {
        DispatchQueue.main.async { [weak self] in
            self?.btConnectState.accept(state)
            
            // 更新连接状态描述 - Update connection state description
            let stateText: String
            switch state {
            case .disconnected:
                stateText = "未连接"
            case .connecting:
                stateText = "连接中"
            case .connected:
                stateText = "已连接"
            case .disconnecting:
                stateText = "断开中"
            @unknown default:
                stateText = "未知"
            }
            self?.connectionState.accept(stateText)
            
            if let peripheral = peripheral {
                print("📡 [DeviceObserver] 蓝牙状态变化 - BT State Changed: \(stateText) | Peripheral: \(peripheral.identifier.uuidString)")
            } else {
                print("📡 [DeviceObserver] 蓝牙状态变化 - BT State Changed: \(stateText)")
            }
        }
    }
    
    /// 监听中央管理器状态变化
    /// Observe central manager state changes
    func observerCentralManagerState(state: CBManagerState) {
        DispatchQueue.main.async { [weak self] in
            let stateText: String
            switch state {
            case .unknown:
                stateText = "未知"
            case .resetting:
                stateText = "重置中"
            case .unsupported:
                stateText = "不支持"
            case .unauthorized:
                stateText = "未授权"
            case .poweredOff:
                stateText = "蓝牙关闭"
            case .poweredOn:
                stateText = "蓝牙开启"
            @unknown default:
                stateText = "未知"
            }
            print("📡 [DeviceObserver] 中央管理器状态 - Central Manager State: \(stateText)")
        }
    }
    
    /// 监听 AI 鉴权结果
    /// Observe AI authentication result
    func observerAIAuthentication(error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                print("❌ [DeviceObserver] AI 鉴权失败 - AI Authentication Failed: \(error.localizedDescription)")
            } else {
                print("✅ [DeviceObserver] AI 鉴权成功 - AI Authentication Succeeded")
            }
        }
    }
}

// MARK: - TSSoudbudObserver Protocol Implementation
extension DeviceObserver {
    
    /// 监听电量变化
    /// Observe power and charging state changes
    func observerPowerChange(leftPower: NSNumber?, leftCharging: NSNumber?, rightPower: NSNumber?, rightCharging: NSNumber?, hubPower: NSNumber?, hubCharging: NSNumber?) {
        DispatchQueue.main.async { [weak self] in
            self?.leftPower.accept(leftPower?.intValue ?? 0)
            self?.rightPower.accept(rightPower?.intValue ?? 0)
            self?.hubPower.accept(hubPower?.intValue ?? 0)
            self?.leftCharging.accept(leftCharging?.boolValue ?? false)
            self?.rightCharging.accept(rightCharging?.boolValue ?? false)
            self?.hubCharging.accept(hubCharging?.boolValue ?? false)
            
            print("🔋 [DeviceObserver] 电量变化 - Power Changed: L:\(leftPower?.intValue ?? 0)%(充电:\(leftCharging?.boolValue ?? false)) R:\(rightPower?.intValue ?? 0)%(充电:\(rightCharging?.boolValue ?? false)) Hub:\(hubPower?.intValue ?? 0)%(充电:\(hubCharging?.boolValue ?? false))")
        }
    }
    
    /// 监听播放状态变化
    /// Observe playback state changes
    func observerPlayStateChange(isPlaying: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying.accept(isPlaying)
            print("🎵 [DeviceObserver] 播放状态 - Play State: \(isPlaying ? "播放中" : "暂停") - \(isPlaying ? "Playing" : "Paused")")
        }
    }
    
    /// 监听工作模式变化
    /// Observe work mode changes
    func observerWorkModeChange(workMode: TSSBEarbudsWorkMode) {
        DispatchQueue.main.async { [weak self] in
            self?.workMode.accept(workMode)
            let modeText = workMode == .normal ? "普通模式" : "游戏模式"
            print("🎮 [DeviceObserver] 工作模式 - Work Mode: \(modeText) - \(workMode == .normal ? "Normal" : "Game")")
        }
    }
    
    /// 监听入耳状态变化
    /// Observe in-ear status changes
    func observerInEarStatusChange(leftInEar: Bool, rightInEar: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.leftInEar.accept(leftInEar)
            self?.rightInEar.accept(rightInEar)
            print("👂 [DeviceObserver] 入耳状态 - In-Ear Status: L:\(leftInEar ? "入耳" : "未入耳") R:\(rightInEar ? "入耳" : "未入耳") - L:\(leftInEar ? "In" : "Out") R:\(rightInEar ? "In" : "Out")")
        }
    }
    
    /// 监听 TWS 连接状态变化
    /// Observe TWS connection status changes
    func observerTWSConnectedChange(isConnected: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.twsConnected.accept(isConnected)
            print("🔗 [DeviceObserver] TWS 连接状态 - TWS Connected: \(isConnected ? "已连接" : "未连接") - \(isConnected ? "Connected" : "Disconnected")")
        }
    }
    
    /// 监听 EQ 设置变化
    /// Observe EQ setting changes
    func observerEQSettingChange(mode: UInt8, gains: [NSNumber]) {
        DispatchQueue.main.async { [weak self] in
            self?.eqMode.accept(Int(mode))
            self?.eqGains.accept(gains.map { $0.intValue })
            print("🎚️ [DeviceObserver] EQ 设置 - EQ Setting: mode=\(mode), gains=\(gains)")
        }
    }
    
    /// 监听设备音量变化
    /// Observe device volume changes
    func observerDeviceVolumeChange(volume: UInt8) {
        DispatchQueue.main.async { [weak self] in
            self?.deviceVolume.accept(Int(volume))
            print("🔊 [DeviceObserver] 设备音量 - Device Volume: \(volume)")
        }
    }
    
    /// 监听 ANC 模式变化
    /// Observe ANC mode changes
    func observerANCModeChange(mode: TSSBEarbudsAncMode) {
        DispatchQueue.main.async { [weak self] in
            self?.ancMode.accept(mode)
            print("🎧 [DeviceObserver] ANC 模式 - ANC Mode: \(mode.rawValue)")
        }
    }
    
    /// 监听 ANC 增益变化
    /// Observe ANC gain changes
    func observerANCGainChange(gain: UInt8) {
        DispatchQueue.main.async { [weak self] in
            self?.ancGain.accept(Int(gain))
            print("🎧 [DeviceObserver] ANC 增益 - ANC Gain: \(gain)")
        }
    }
    
    /// 监听透传增益变化
    /// Observe transparency gain changes
    func observerTransparencyGainChange(gain: UInt8) {
        DispatchQueue.main.async { [weak self] in
            self?.transparencyGain.accept(Int(gain))
            print("🎧 [DeviceObserver] 透传增益 - Transparency Gain: \(gain)")
        }
    }
    
    /// 监听 3D 音效变化
    /// Observe 3D sound effect changes
    func observerSoundEffect3DChange(isEnabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.soundEffect3DEnabled.accept(isEnabled)
            print("🎵 [DeviceObserver] 3D 音效 - 3D Sound Effect: \(isEnabled ? "开启" : "关闭") - \(isEnabled ? "Enabled" : "Disabled")")
        }
    }
    
    /// 监听低音引擎状态变化
    /// Observe bass engine status changes
    func observerBassEngineStatusChange(isEnabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.bassEngineEnabled.accept(isEnabled)
            print("🎵 [DeviceObserver] 低音引擎 - Bass Engine: \(isEnabled ? "开启" : "关闭") - \(isEnabled ? "Enabled" : "Disabled")")
        }
    }
    
    /// 监听按键设置变化
    /// Observe key settings changes
    func observerKeySettingsChange(operations: [NSNumber], functions: [NSNumber]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var mapping: [TSSBEarbudsDeviceOperationType: TSSBEarbudsKeyFunction] = [:]
            for (operationValue, functionValue) in zip(operations, functions) {
                guard
                    let operation = TSSBEarbudsDeviceOperationType(rawValue: operationValue.uint8Value),
                    let function = TSSBEarbudsKeyFunction(rawValue: functionValue.uint8Value)
                else { continue }
                mapping[operation] = function
            }
            if !mapping.isEmpty {
                self.keyOperationMap.accept(mapping)
            }
            print("⌨️ [DeviceObserver] 按键设置 - Key Settings: operations=\(operations), functions=\(functions)")
        }
    }
    
    /// 监听提示音类型变化
    /// Observe prompt tone type changes
    func observerPromptToneTypeChange(type: UInt8) {
        DispatchQueue.main.async { [weak self] in
            self?.promptToneType.accept(type)
            print("🔔 [DeviceObserver] 提示音类型 - Prompt Tone Type: \(type)")
        }
    }
    
    /// 监听 LED 开关变化
    /// Observe LED switch changes
    func observerLEDSwitchChange(isOn: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.ledEnabled.accept(isOn)
            print("💡 [DeviceObserver] LED 开关 - LED Switch: \(isOn ? "开启" : "关闭") - \(isOn ? "On" : "Off")")
        }
    }
    
    /// 监听主侧变化
    /// Observe main side changes
    func observerMainSideChange(isLeft: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isLeftMain.accept(isLeft)
            print("👂 [DeviceObserver] 主侧 - Main Side: \(isLeft ? "左耳" : "右耳") - \(isLeft ? "Left" : "Right")")
        }
    }
    
    /// 监听多点连接状态变化
    /// Observe multipoint status changes
    func observerMultipointStatusChange(isEnabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.multipointEnabled.accept(isEnabled)
            print("🔗 [DeviceObserver] 多点连接 - Multipoint: \(isEnabled ? "开启" : "关闭") - \(isEnabled ? "Enabled" : "Disabled")")
        }
    }
    
    /// 监听多点信息变化
    /// Observe multipoint info changes
    func observerMultipointInfoChange(devices: [NSDictionary]) {
        DispatchQueue.main.async { [weak self] in
            print("🔗 [DeviceObserver] 多点信息 - Multipoint Info: \(devices.count) devices")
        }
    }
    
    /// 监听语音识别变化
    /// Observe voice recognition changes
    func observerVoiceRecognitionChange(isEnabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.voiceRecognitionEnabled.accept(isEnabled)
            print("🎤 [DeviceObserver] 语音识别 - Voice Recognition: \(isEnabled ? "开启" : "关闭") - \(isEnabled ? "Enabled" : "Disabled")")
        }
    }
    
    /// 监听远程相机控制状态
    /// Observe remote camera control state
    func observerRemoteCameraControlState(state: UInt8) {
        DispatchQueue.main.async { [weak self] in
            if let cameraState = TSSBRemoteCameraState(rawValue: state) {
                self?.remoteCameraState.accept(cameraState)
            } else {
                self?.remoteCameraState.accept(nil)
            }
            print("📷 [DeviceObserver] 远程相机控制 - Remote Camera Control: state=\(state)")
        }
    }
    
    /// 监听设备存储空间信息
    /// Observe device storage space
    @objc func observerDeviceStorageSpaceNotify(usedSpaceMb: UInt32, freeSpaceMb: UInt32) {
        DispatchQueue.main.async { [weak self] in
            self?.storageSpace.accept((usedSpaceMb, freeSpaceMb))
            print("💾 [DeviceObserver] 存储空间 - Storage: 已用=\(usedSpaceMb)MB, 剩余=\(freeSpaceMb)MB")
        }
    }
    
    /// 监听媒体数量变化
    /// Observe media count changes
    func observerMediaCountDidChanged(picCount: UInt32, videoCount: UInt32, audioCount: UInt32) {
        DispatchQueue.main.async { [weak self] in
            self?.mediaCount.accept((picCount, videoCount, audioCount))
            print("📁 [DeviceObserver] 媒体数量 - Media Count: 图片/Images=\(picCount), 视频/Videos=\(videoCount), 音频/Audios=\(audioCount)")
        }
    }
    
    /// 监听 WiFi 状态变化
    /// Observe WiFi state changes
    func observerWifiStateChanged(state: TSSBEarbudsWiFiState) {
        DispatchQueue.main.async { [weak self] in
            self?.wifiState.accept(state)
            print("📶 [DeviceObserver] WiFi 状态 - WiFi State: \(state.rawValue)")
        }
    }
    
    /// 监听 WiFi 地址通知
    /// Observe WiFi address notification
    func observerWifiAddressNotify(wifiAddress: String) {
        DispatchQueue.main.async { [weak self] in
            self?.wifiAddress.accept(wifiAddress)
            print("📶 [DeviceObserver] WiFi 地址 - WiFi Address: \(wifiAddress)")
        }
    }
    
    /// 监听 AI 录音通知
    /// Observe AI record notification
    func observerAIRecordNotify(recordData: Data?) {
        DispatchQueue.main.async { [weak self] in
            let length = recordData?.count ?? 0
            print("🎤 [DeviceObserver] AI 录音 - AI Record: dataLength=\(length)")
        }
    }
    
    /// 监听 AI 状态通知
    /// Observe AI state notification
    func observerAIStateNotify(status: Data) {
        DispatchQueue.main.async { [weak self] in
            print("🤖 [DeviceObserver] AI 状态 - AI State: dataLength=\(status.count)")
        }
    }
    
    /// 监听是否支持通话录音通知
    /// Observe call record support notification
    func observerIsSupportCallRecordNotify(status: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.supportCallRecord.accept(status)
            print("📞 [DeviceObserver] 支持通话录音 - Support Call Record: \(status ? "是" : "否") - \(status ? "Yes" : "No")")
        }
    }
    
    /// 监听 AI 聊天图片通知
    /// Observe AI chat image notification
    func observerAIChatImageNotify(imageData: Data) {
        DispatchQueue.main.async { [weak self] in
            print("🖼️ [DeviceObserver] AI 聊天图片 - AI Chat Image: dataLength=\(imageData.count)")
        }
    }
    
    /// 监听子固件版本通知
    /// Observe sub firmware version notification
    func observerSubFirmwareVersionNotify(version: String) {
        DispatchQueue.main.async { [weak self] in
            self?.subFirmwareVersion.accept(version)
            print("📱 [DeviceObserver] 子固件版本 - Sub Firmware Version: \(version)")
        }
    }
    
    /// 监听设备工作状态通知
    /// Observe device work state notification
    func observerDeviceWorkStateNotify(state: UInt8) {
        DispatchQueue.main.async { [weak self] in
            self?.deviceWorkStateRaw.accept(state)
            print("⚙️ [DeviceObserver] 工作状态通知 - Work State Notify: \(state)")
        }
    }
}

