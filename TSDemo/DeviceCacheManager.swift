//
//  DeviceCacheManager.swift
//  TSDemo
//
//  设备缓存管理器 - Device Cache Manager
//  用于管理设备信息的本地持久化存储
//  Manages local persistent storage of device information
//

import Foundation
import TopStepABMateSDK

/// 设备缓存管理器
/// Device cache manager for storing and retrieving device information
class DeviceCacheManager {
    
    // MARK: - Singleton
    /// 单例实例 - Singleton instance
    static let shared = DeviceCacheManager()
    
    // MARK: - Properties
    /// UserDefaults 实例 - UserDefaults instance
    private let userDefaults = UserDefaults.standard
    
    /// 缓存键值常量 - Cache key constants
    private let deviceUUIDKey = "cached_device_uuid"
    private let deviceNameKey = "cached_device_name"
    private let deviceMacKey = "cached_device_mac"
    private let deviceCategoryKey = "cached_device_category"
    private let deviceSDKTypeKey = "cached_device_sdk_type"
    private let deviceTypeKey = "cached_device_type"
    
    // MARK: - Initialization
    /// 私有初始化方法，确保单例模式 - Private initializer to ensure singleton
    private init() {}
    
    // MARK: - Public Methods
    
    /// 保存设备信息到缓存（保存完整的设备信息）
    /// Save complete device information to cache
    /// - Parameter device: 要缓存的完整设备信息 - Complete device info to cache
    func saveDevice(_ device: TSDeviceBaseInfo) {
        // 保存基础信息 - Save basic information
        userDefaults.set(device.uuid, forKey: deviceUUIDKey)
        userDefaults.set(device.name, forKey: deviceNameKey)
        userDefaults.set(device.mac, forKey: deviceMacKey)
        userDefaults.set(device.deviceCategory.rawValue, forKey: deviceCategoryKey)
        
        // 保存SDK类型和设备类型 - Save SDK type and device type
        userDefaults.set(device.sdkType.rawValue, forKey: deviceSDKTypeKey)
        userDefaults.set(device.deviceType.rawValue, forKey: deviceTypeKey)
        
        // 注意：advDataInfo 是可选对象，暂不缓存，连接时会重新获取
        // Note: advDataInfo is optional and complex, not cached here, will be retrieved during connection
        
        userDefaults.synchronize()
        
        print("✅ 设备已缓存（完整信息）- Device cached (complete info): \(device.name) (\(device.uuid))")
        print("   SDK类型/SDK Type: \(device.sdkType.rawValue), 设备类型/Device Type: \(device.deviceType.rawValue), 分类/Category: \(device.deviceCategory.rawValue)")
    }
    
    /// 从缓存读取完整的设备信息
    /// Retrieve complete device information from cache
    /// - Returns: 缓存的完整设备信息，如果没有则返回 nil - Complete cached device info, or nil if not found
    func getCachedDevice() -> TSDeviceBaseInfo? {
        // 读取基础信息 - Read basic information
        guard let uuid = userDefaults.string(forKey: deviceUUIDKey),
              let name = userDefaults.string(forKey: deviceNameKey),
              let mac = userDefaults.string(forKey: deviceMacKey),
              let categoryRaw = userDefaults.object(forKey: deviceCategoryKey) as? Int,
              let sdkTypeRaw = userDefaults.object(forKey: deviceSDKTypeKey) as? Int,
              let deviceTypeRaw = userDefaults.object(forKey: deviceTypeKey) as? Int else {
            print("ℹ️ 没有缓存的设备 - No cached device found")
            return nil
        }
        
        // 转换枚举类型 - Convert enum types
        let sdkType = TPSSDKType(rawValue: UInt8(sdkTypeRaw)) ?? TPSSDKType(rawValue: 0)!
        let deviceType = TPSDeviceType(rawValue: UInt(deviceTypeRaw)) ?? TPSDeviceType(rawValue: 0)!
        let deviceCategory = TPSDeviceCategory(rawValue: categoryRaw) ?? TPSDeviceCategory(rawValue: 0)!
        
        // 使用完整的初始化方法创建设备对象 - Create device object using full initializer
        let device = TSDeviceBaseInfo(
            sdkType: sdkType,
            deviceType: deviceType,
            deviceCategory: deviceCategory,
            mac: mac,
            name: name,
            uuid: uuid
        )
        
        print("✅ 读取缓存设备（完整信息）- Retrieved cached device (complete info): \(name) (\(uuid))")
        print("   SDK类型/SDK Type: \(device.sdkType.rawValue), 设备类型/Device Type: \(device.deviceType.rawValue), 分类/Category: \(device.deviceCategory.rawValue)")
        return device
    }
    
    /// 清除缓存的设备信息（清除所有相关键值）
    /// Clear cached device information (remove all related keys)
    func clearCache() {
        userDefaults.removeObject(forKey: deviceUUIDKey)
        userDefaults.removeObject(forKey: deviceNameKey)
        userDefaults.removeObject(forKey: deviceMacKey)
        userDefaults.removeObject(forKey: deviceCategoryKey)
        userDefaults.removeObject(forKey: deviceSDKTypeKey)
        userDefaults.removeObject(forKey: deviceTypeKey)
        userDefaults.synchronize()
        
        print("🗑️ 设备缓存已清除（所有信息）- Device cache cleared (all info)")
    }
    
    /// 检查是否有缓存设备
    /// Check if there is a cached device
    /// - Returns: true 如果有缓存设备 - true if device is cached
    func hasCachedDevice() -> Bool {
        let hasCached = userDefaults.string(forKey: deviceUUIDKey) != nil
        print("ℹ️ 缓存检查 - Cache check: \(hasCached ? "有缓存设备" : "无缓存设备") - \(hasCached ? "Has cached device" : "No cached device")")
        return hasCached
    }
}

