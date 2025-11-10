//
//  DeviceSupportFunction.swift
//  TSDemo
//
//  设备支持功能模型 - Device Support Function Model
//  用于判断设备是否支持特定功能
//

import Foundation
import TopStepABMateSDK

/// 设备支持功能
/// Device support function
struct DeviceSupportFunction {
    /// 是否支持 ANC
    var isSupportANC: Bool = true
    
    /// 是否支持 EQ
    var isSupportEQ: Bool = true
    
    /// 是否支持 3D 音效
    var isSupportSoundEffect3D: Bool = true
    
    /// 是否支持低音引擎
    var isSupportBassEngine: Bool = true
    
    /// 是否支持音乐控制
    var isSupportMusicControl: Bool = true
    
    /// 是否支持工作模式
    var isSupportWorkMode: Bool = true
    
    /// 是否支持入耳检测
    var isSupportInEarDetect: Bool = true
    
    /// 是否支持查找设备
    var isSupportFindDevice: Bool = true
    
    /// 是否支持 LED
    var isSupportLED: Bool = true
    
    /// 是否支持多点连接
    var isSupportMultipoint: Bool = true
    
    /// 是否支持语音识别
    var isSupportVoiceRecognition: Bool = true
    
    /// 是否支持 OTA
    var isSupportOTA: Bool = true
    
    /// 是否支持 AI 功能
    var isSupportAI: Bool = true
    
    /// 是否支持相机/媒体
    var isSupportMedia: Bool = true
    
    /// 是否支持 WiFi
    var isSupportWiFi: Bool = true
    
    /// 是否支持存储查询
    var isSupportStorage: Bool = true
    
    /// 默认支持所有功能（向后兼容）
    /// Default support all functions (backward compatible)
    init() {
        // 默认值已在属性声明中设置
    }
    
    /// 从设备信息字典解析支持功能
    /// Parse support function from device info dictionary
    init?(from deviceInfo: [String: Any]) {
        // 根据设备信息类型判断支持情况
        // SDK 返回的字典键可能是字符串格式的十六进制值（如 "0x0C"）或数字
        
        // 辅助函数：检查设备信息中是否包含指定类型
        func hasDeviceInfoType(_ type: TSSBEarbudsDeviceInfoType) -> Bool {
            let typeValue = type.rawValue
            // 常见的键格式：十六进制（带或不带0x前缀）、十进制字符串
            let keyCandidates: [String] = [
                String(format: "0x%02X", typeValue),
                String(format: "0x%02x", typeValue),
                String(format: "%02X", typeValue),
                String(format: "%02x", typeValue),
                String(typeValue),
                "\(typeValue)"
            ]
            
            for key in keyCandidates {
                if deviceInfo[key] != nil {
                    return true
                }
            }
            return false
        }
        
        // ANC 相关
        if hasDeviceInfoType(.ancMode) || hasDeviceInfoType(.ancGain) {
            self.isSupportANC = true
        }
        
        // EQ 相关
        if hasDeviceInfoType(.allEqSettings) || hasDeviceInfoType(.eqSetting) {
            self.isSupportEQ = true
        }
        
        // 3D 音效
        if hasDeviceInfoType(.soundEffect3D) {
            self.isSupportSoundEffect3D = true
        }
        
        // 低音引擎
        if hasDeviceInfoType(.bassEngineStatus) || hasDeviceInfoType(.bassEngineValue) {
            self.isSupportBassEngine = true
        }
        
        // 工作模式
        if hasDeviceInfoType(.workMode) {
            self.isSupportWorkMode = true
        }
        
        // 入耳检测
        if hasDeviceInfoType(.inEarStatus) {
            self.isSupportInEarDetect = true
        }
        
        // LED
        if hasDeviceInfoType(.ledSwitch) {
            self.isSupportLED = true
        }
        
        // 多点连接
        if hasDeviceInfoType(.multipointStatus) || hasDeviceInfoType(.multipointInfo) {
            self.isSupportMultipoint = true
        }
        
        // 语音识别
        if hasDeviceInfoType(.voiceRecognition) {
            self.isSupportVoiceRecognition = true
        }
        
        // 播放状态（用于判断音乐控制）
        if hasDeviceInfoType(.playState) {
            self.isSupportMusicControl = true
        }
        
        // 注意：WiFi、OTA、AI、Media、Storage 等功能可能需要通过其他方式判断
        // 目前默认支持，后续可以根据实际设备信息类型补充
    }
}

/// 设备支持功能管理器
/// Device support function manager
class DeviceSupportFunctionManager {
    
    static let shared = DeviceSupportFunctionManager()
    
    private var supportFunction: DeviceSupportFunction?
    private let userDefaults = UserDefaults.standard
    private let supportFunctionKey = "DeviceSupportFunction"
    
    private init() {}
    
    /// 获取设备支持功能（优先从缓存读取）
    /// Get device support function (prefer cache)
    func getSupportFunction() -> DeviceSupportFunction {
        if let cached = supportFunction {
            return cached
        }
        
        // 从 UserDefaults 读取
        if let data = userDefaults.data(forKey: supportFunctionKey),
           let decoded = try? JSONDecoder().decode(DeviceSupportFunction.self, from: data) {
            supportFunction = decoded
            return decoded
        }
        
        // 默认返回支持所有功能
        return DeviceSupportFunction()
    }
    
    /// 更新设备支持功能
    /// Update device support function
    func updateSupportFunction(_ function: DeviceSupportFunction) {
        supportFunction = function
        
        // 保存到 UserDefaults
        if let encoded = try? JSONEncoder().encode(function) {
            userDefaults.set(encoded, forKey: supportFunctionKey)
        }
    }
    
    /// 清除缓存
    /// Clear cache
    func clearCache() {
        supportFunction = nil
        userDefaults.removeObject(forKey: supportFunctionKey)
    }
    
    /// 查询设备支持功能（从设备获取）
    /// Query device support function (from device)
    func querySupportFunction(device: TSSBEarbuds, completion: @escaping (DeviceSupportFunction) -> Void) {
        device.commandManager.queryABMateDeviceinfo { [weak self] deviceInfo, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 查询设备信息失败: \(error.localizedDescription)")
                    // 返回默认支持所有功能（向后兼容）
                    let defaultFunction = DeviceSupportFunction()
                    self?.updateSupportFunction(defaultFunction)
                    completion(defaultFunction)
                    return
                }
                
                if let deviceInfo = deviceInfo {
                    print("📋 设备信息: \(deviceInfo)")
                    // 从设备信息解析支持功能
                    // 如果解析失败，使用默认值（支持所有功能）
                    let function = DeviceSupportFunction(from: deviceInfo) ?? DeviceSupportFunction()
                    self?.updateSupportFunction(function)
                    print("✅ 解析后的支持功能: ANC=\(function.isSupportANC), EQ=\(function.isSupportEQ), 3D=\(function.isSupportSoundEffect3D)")
                    completion(function)
                } else {
                    // 返回默认支持所有功能
                    let defaultFunction = DeviceSupportFunction()
                    self?.updateSupportFunction(defaultFunction)
                    completion(defaultFunction)
                }
            }
        }
    }
}

// MARK: - Codable
extension DeviceSupportFunction: Codable {
    enum CodingKeys: String, CodingKey {
        case isSupportANC
        case isSupportEQ
        case isSupportSoundEffect3D
        case isSupportBassEngine
        case isSupportMusicControl
        case isSupportWorkMode
        case isSupportInEarDetect
        case isSupportFindDevice
        case isSupportLED
        case isSupportMultipoint
        case isSupportVoiceRecognition
        case isSupportOTA
        case isSupportAI
        case isSupportMedia
        case isSupportWiFi
        case isSupportStorage
    }
}

