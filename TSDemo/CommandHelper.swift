//
//  CommandHelper.swift
//  TSDemo
//
//  指令辅助类 - Command Helper
//  提供指令分类和名称映射
//

import Foundation
import TopStepABMateSDK

/// 指令分类类型
/// Command category type
enum CommandCategoryType {
    case audio
    case deviceOperation
    case deviceInfo
    case media
    case storage
    case other
}

/// 指令分类
/// Command category
struct CommandCategory {
    let name: String
    let type: CommandCategoryType
    let commands: [TSSBEarbudsCommand]
}

/// 指令辅助类
/// Command helper class
struct CommandHelper {
    
    /// 获取所有指令分类
    /// Get all command categories
    static func getAllCategories() -> [CommandCategory] {
        return [
            CommandCategory(
                name: "音效相关",
                type: .audio,
                commands: [
                    .eq,
                    .musicControl,
                    .ancMode,
                    .ancGain,
                    .transparencyGain,
                    .soundEffect3D,
                    .anc,
                    .bassEngine
                ]
            ),
            CommandCategory(
                name: "设备操作",
                type: .deviceOperation,
                commands: [
                    .deviceOperation,
                    .factoryReset,
                    .workMode,
                    .inEarDetect,
                    .findDevice,
                    .autoAnswer,
                    .bluetoothName,
                    .ledMode,
                    .clearPairRecord,
                    .multipoint,
                    .voiceRecognition
                ]
            ),
            CommandCategory(
                name: "设备信息",
                type: .deviceInfo,
                commands: [
                    .deviceInfo,
                    .deviceInfoNotify,
                    .promptTone,
                    .autoShutdown
                ]
            ),
            CommandCategory(
                name: "相机/媒体",
                type: .media,
                commands: [
                    .remoteCamera,
                    .startCameraAndTakephoto,
                    .shutDownRecord,
                    .startAudioRecord,
                    .takeVideoRecord
                ]
            ),
            CommandCategory(
                name: "存储/时间",
                type: .storage,
                commands: [
                    .getStorageInfo,
                    .getMediaCount,
                    .setStandardTime,
                    .subFirmwareVersion
                ]
            ),
            CommandCategory(
                name: "其他",
                type: .other,
                commands: [
                    .deviceAuthentication,
                    .deviceWorkState,
                    .deviceDebug
                ]
            )
        ]
    }
    
    /// 判断指令是否属于音效类
    static func isAudioCommand(_ command: TSSBEarbudsCommand) -> Bool {
        return getAllCategories()
            .first(where: { $0.type == .audio })?
            .commands
            .contains(command) ?? false
    }
    
    /// 判断指令是否被设备支持
    /// Check if command is supported by device
    static func isCommandSupported(_ command: TSSBEarbudsCommand, supportFunction: DeviceSupportFunction) -> Bool {
        switch command {
        case .eq:
            return supportFunction.isSupportEQ
        case .musicControl:
            return supportFunction.isSupportMusicControl
        case .ancMode, .ancGain, .transparencyGain, .anc:
            return supportFunction.isSupportANC
        case .soundEffect3D:
            return supportFunction.isSupportSoundEffect3D
        case .bassEngine:
            return supportFunction.isSupportBassEngine
        case .workMode:
            return supportFunction.isSupportWorkMode
        case .inEarDetect:
            return supportFunction.isSupportInEarDetect
        case .findDevice:
            return supportFunction.isSupportFindDevice
        case .ledMode:
            return supportFunction.isSupportLED
        case .multipoint:
            return supportFunction.isSupportMultipoint
        case .voiceRecognition:
            return supportFunction.isSupportVoiceRecognition
        case .otaAllowedRequest, .beginOTARequest, .subseqOTARequest, .otaStateNofity:
            return supportFunction.isSupportOTA
        case .setAIChatState, .controlAIRecord, .aiRecordDataNotify, .aiChatImageNotify:
            return supportFunction.isSupportAI
        case .remoteCamera, .startCameraAndTakephoto, .shutDownRecord, .startAudioRecord, .takeVideoRecord:
            return supportFunction.isSupportMedia
        case .wifiSetting, .startFileTransfer, .wifitStateChanged:
            return supportFunction.isSupportWiFi
        case .getStorageInfo, .getMediaCount, .setStandardTime:
            return supportFunction.isSupportStorage
        default:
            // 其他指令默认支持（向后兼容）
            return true
        }
    }
    
    /// 获取指令名称
    /// Get command name
    static func getCommandName(_ command: TSSBEarbudsCommand) -> String {
        switch command {
        case .eq:
            return "EQ音效设置"
        case .musicControl:
            return "音乐播放控制"
        case .deviceOperation:
            return "耳机操作设置"
        case .autoShutdown:
            return "定时关机设置"
        case .factoryReset:
            return "设备端恢复出厂设置"
        case .workMode:
            return "工作模式设置"
        case .inEarDetect:
            return "入耳检测设置"
        case .deviceInfo:
            return "获取设备信息"
        case .deviceInfoNotify:
            return "设备端上报设备信息"
        case .promptTone:
            return "提示音设置"
        case .findDevice:
            return "查找耳机"
        case .autoAnswer:
            return "来电自动接听设置"
        case .ancMode:
            return "ANC模式设置"
        case .bluetoothName:
            return "设备蓝牙名设置"
        case .ledMode:
            return "LED灯开关设置"
        case .clearPairRecord:
            return "清除与手机的所有配对记录"
        case .ancGain:
            return "降噪等级设置"
        case .transparencyGain:
            return "通透等级设置"
        case .soundEffect3D:
            return "3D音效开关设置"
        case .multipoint:
            return "1拖2相关设置"
        case .voiceRecognition:
            return "语音识别开关设置"
        case .anc:
            return "ANC相关设置"
        case .bassEngine:
            return "动态低音相关设置"
        case .remoteCamera:
            return "遥控拍照"
        case .otaAllowedRequest:
            return "是否允许OTA请求"
        case .beginOTARequest:
            return "OTA第一次请求"
        case .subseqOTARequest:
            return "OTA后续请求"
        case .otaStateNofity:
            return "OTA状态反馈"
        case .setAIChatState:
            return "设置AI对话开关状态"
        case .controlAIRecord:
            return "打开/关闭录音"
        case .startCameraAndTakephoto:
            return "打开摄像头并立即拍照"
        case .shutDownRecord:
            return "关闭拍照、录像、文件传输等"
        case .startAudioRecord:
            return "开始音频录制"
        case .wifiSetting:
            return "WiFi设置"
        case .startFileTransfer:
            return "开始文件传输"
        case .wifitStateChanged:
            return "WiFi状态变化"
        case .getStorageInfo:
            return "获取存储信息"
        case .getMediaCount:
            return "获取媒体数量"
        case .setStandardTime:
            return "设置标准时间"
        case .aiRecordDataNotify:
            return "AI录音数据通知"
        case .subFirmwareVersion:
            return "子固件版本"
        case .aiChatImageNotify:
            return "AI对话图片通知"
        case .takeVideoRecord:
            return "录制视频"
        case .deviceAuthentication:
            return "设备认证"
        case .deviceWorkState:
            return "设备工作状态"
        case .deviceDebug:
            return "设备调试"
        @unknown default:
            return "未知指令"
        }
    }
    
    /// 指令16进制字符串
    static func hexString(for command: TSSBEarbudsCommand) -> String {
        return String(format: "0x%02X", command.rawValue)
    }
}

