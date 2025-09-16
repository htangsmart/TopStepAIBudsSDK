# TSDemo - TopStep AI Buds SDK Demo

## 功能说明 / Features

本 Demo 展示如何使用 `TopStepAIBudsSDK` 完成以下功能：

This demo demonstrates how to use `TopStepAIBudsSDK` to accomplish the following features:

- **选择设备 / Device Selection**: 进入扫描页，实时展示扫描到的设备，点击返回所选设备到首页
  - Enter scan page, display discovered devices in real-time, tap to return selected device to home page
- **连接设备 / Device Connection**: 在首页点击"连接设备"，若未选择设备会提示；已选择则调用 SDK 连接
  - Click "Connect Device" on home page, prompt if no device selected; otherwise call SDK to connect

## 运行环境 / Requirements

- iOS 13.4+
- Swift 5+

## 权限配置 / Permissions Configuration

已在 `TSDemo/Info.plist` 配置 / Already configured in `TSDemo/Info.plist`:

- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`
- 可选 / Optional: `UIBackgroundModes` 中包含 / containing `bluetooth-central`/`bluetooth-peripheral`/`audio`

## 主要文件 / Main Files

- `TSDemo/ViewController.swift`: 首页，包含"选择设备/连接设备" / Home page with "Select Device/Connect Device"
- `TSDemo/ScanViewController.swift`: 扫描设备列表页 / Device scanning list page

## 使用步骤 / Usage Steps

1. 打开 App 进入首页 / Open App and enter home page
2. 点击"功能1：选择设备"进入扫描页，等待列表出现，点击某设备返回首页 / Click "Feature 1: Select Device" to enter scan page, wait for list to appear, tap a device to return to home page
3. 点击"功能2：连接设备"，若已选择设备则发起连接，成功后首页展示"已连接" / Click "Feature 2: Connect Device", if device is selected then initiate connection, display "Connected" on home page after success

## 关键 API / Key APIs

### 扫描 / Scanning
```swift
TopStepAIBuds.scanDevice { error, deviceInfo, peripheral in 
    // 更新列表 / Update list
}
TopStepAIBuds.stopScan()
```

### 连接 / Connection
```swift
TopStepAIBuds.connectDevice(
    uuid: device.uuid, 
    connectStyle: .BLE, 
    category: device.deviceCategory, 
    deviceObserver: nil
) { error, info, peripheral in 
    // 连接结果 / Connection result
}
```

## 注意事项 / Notes

- 真机调试需要蓝牙权限；模拟器不支持蓝牙 / Real device debugging requires Bluetooth permissions; simulator doesn't support Bluetooth
- 若扫描较久无结果，请确认设备处于可被发现状态并靠近手机 / If scanning takes too long with no results, ensure device is discoverable and close to phone

## 项目结构 / Project Structure

```
TSDemo/
├── TSDemo/
│   ├── ViewController.swift          # 主页面控制器 / Main view controller
│   ├── ScanViewController.swift      # 设备扫描页面 / Device scanning page
│   ├── AppDelegate.swift            # 应用程序代理 / App delegate
│   └── SceneDelegate.swift          # 场景代理 / Scene delegate
├── SDK/
│   └── TopStepAIBudsSDK.xcframework # TopStep AI Buds SDK
├── Podfile                          # CocoaPods 依赖配置 / CocoaPods dependencies
└── README.md                        # 项目说明文档 / Project documentation
```

## 开发指南 / Development Guide

### 安装 / Instal
```bash
  pod 'TopStepAIBudsSDK', :git => 'https://github.com/htangsmart/TopStepAIBudsSDK.git', :branch => 'master'
```
#### 项目配置
1. Target -> Build Settings ->  User Script Sandboxing 设置为NO
2. Pods需要指定最低版本

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "12.0"
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    end
  end  
end

### 运行项目 / Run Project
1. 打开 `TSDemo.xcworkspace` / Open `TSDemo.xcworkspace`
2. 选择目标设备 / Select target device
3. 运行项目 / Run the project

### 调试建议 / Debugging Tips
- 确保在真机上测试蓝牙功能 / Ensure testing Bluetooth functionality on real device
- 检查设备蓝牙权限设置 / Check device Bluetooth permission settings
- 查看控制台日志获取详细错误信息 / Check console logs for detailed error information


