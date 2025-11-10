//
//  DeviceSupportFunction+Extension.swift
//  TSDemo
//
//  设备支持功能扩展 - Device Support Function Extension
//  提供便捷的访问方法供其他功能使用
//

import Foundation
import TopStepABMateSDK

// MARK: - DeviceObserver Extension
extension DeviceObserver {
    
    /// 检查设备是否支持指定指令
    /// Check if device supports specified command
    func isCommandSupported(_ command: TSSBEarbudsCommand) -> Bool {
        return CommandHelper.isCommandSupported(command, supportFunction: supportFunction.value)
    }
    
    /// 检查设备是否支持 ANC
    /// Check if device supports ANC
    var supportsANC: Bool {
        return supportFunction.value.isSupportANC
    }
    
    /// 检查设备是否支持 EQ
    /// Check if device supports EQ
    var supportsEQ: Bool {
        return supportFunction.value.isSupportEQ
    }
    
    /// 检查设备是否支持 3D 音效
    /// Check if device supports 3D sound effect
    var supportsSoundEffect3D: Bool {
        return supportFunction.value.isSupportSoundEffect3D
    }
    
    /// 检查设备是否支持低音引擎
    /// Check if device supports bass engine
    var supportsBassEngine: Bool {
        return supportFunction.value.isSupportBassEngine
    }
    
    /// 检查设备是否支持音乐控制
    /// Check if device supports music control
    var supportsMusicControl: Bool {
        return supportFunction.value.isSupportMusicControl
    }
    
    /// 检查设备是否支持工作模式
    /// Check if device supports work mode
    var supportsWorkMode: Bool {
        return supportFunction.value.isSupportWorkMode
    }
    
    /// 检查设备是否支持入耳检测
    /// Check if device supports in-ear detection
    var supportsInEarDetect: Bool {
        return supportFunction.value.isSupportInEarDetect
    }
    
    /// 检查设备是否支持查找设备
    /// Check if device supports find device
    var supportsFindDevice: Bool {
        return supportFunction.value.isSupportFindDevice
    }
    
    /// 检查设备是否支持 LED
    /// Check if device supports LED
    var supportsLED: Bool {
        return supportFunction.value.isSupportLED
    }
    
    /// 检查设备是否支持多点连接
    /// Check if device supports multipoint
    var supportsMultipoint: Bool {
        return supportFunction.value.isSupportMultipoint
    }
    
    /// 检查设备是否支持语音识别
    /// Check if device supports voice recognition
    var supportsVoiceRecognition: Bool {
        return supportFunction.value.isSupportVoiceRecognition
    }
    
    /// 检查设备是否支持 OTA
    /// Check if device supports OTA
    var supportsOTA: Bool {
        return supportFunction.value.isSupportOTA
    }
    
    /// 检查设备是否支持 AI
    /// Check if device supports AI
    var supportsAI: Bool {
        return supportFunction.value.isSupportAI
    }
    
    /// 检查设备是否支持媒体功能
    /// Check if device supports media
    var supportsMedia: Bool {
        return supportFunction.value.isSupportMedia
    }
    
    /// 检查设备是否支持 WiFi
    /// Check if device supports WiFi
    var supportsWiFi: Bool {
        return supportFunction.value.isSupportWiFi
    }
    
    /// 检查设备是否支持存储查询
    /// Check if device supports storage
    var supportsStorage: Bool {
        return supportFunction.value.isSupportStorage
    }
}

// MARK: - CommandCategory Extension
extension CommandCategory {
    
    /// 获取该分类下设备支持的指令列表
    /// Get supported commands in this category
    func getSupportedCommands(supportFunction: DeviceSupportFunction) -> [TSSBEarbudsCommand] {
        return commands.filter { command in
            CommandHelper.isCommandSupported(command, supportFunction: supportFunction)
        }
    }
}

