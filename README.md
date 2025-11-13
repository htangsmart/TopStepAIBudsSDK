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

## CocoaPods 发布指南 / CocoaPods Release Guide

### 前置条件 / Prerequisites
- 拥有一个可以访问的 Git 仓库，并确保 `TopStepABMateSDK.xcframework`、`AWEISIMG_SDK.framework` 已提交 / Ensure the Git repository contains both vendored frameworks.
- 在仓库根目录提供有效的 `LICENSE`（已添加 MIT License）和本 README 文档 / Provide a valid `LICENSE` and this README at the repo root.
- 本地已安装 CocoaPods 1.12.0 及以上版本 / Install CocoaPods 1.12.0+ locally: `sudo gem install cocoapods`.
- 注册并验证 CocoaPods Trunk 账号 / Register and verify CocoaPods Trunk:
  ```bash
  pod trunk register your_email@example.com 'Your Name' --description='TopStep release Mac'
  ```

### 发布流程 / Release Steps
1. **更新版本号 / Bump Version**
   - 修改 `TopStepAIBudsSDK.podspec` 中的 `s.version` 并创建对应的 Git 标签，例如：
     ```bash
     git commit -am "chore: bump version to 1.0.0"
     git tag 1.0.0
     git push origin main --tags
     ```
2. **本地校验 / Local Validation**
   - 由于三方二进制框架仅支持 arm64（真机），需要跳过导入验证：
     ```bash
     pod spec lint TopStepAIBudsSDK.podspec \
       --skip-import-validation \
       --allow-warnings \
       --verbose
     ```
   - 如果希望在模拟器运行 Demo，请向供应商索取包含模拟器 slice 的框架并替换仓库中的二进制文件 / Request simulator slices from vendors if simulator support is required.
3. **推送到 Trunk / Push to Trunk**
   ```bash
   pod trunk push TopStepAIBudsSDK.podspec \
     --skip-import-validation \
     --allow-warnings \
     --verbose
   ```
4. **发布验证 / Post-publish Validation**
   - 在新的空白工程中尝试 `pod init` 并引入：
     ```ruby
     pod 'TopStepAIBudsSDK', '~> 1.0'
     ```
   - 确认工程能在真机编译通过，调试功能与 Demo 一致。

### 常见问题 / FAQ
- **为什么模拟器编译失败？ / Why does the simulator fail to build?**  
  当前二进制框架仅包含 arm64 真机架构。若需要模拟器调试，请获取并合并对应的 simulator slice，然后使用 `xcodebuild -create-xcframework` 重新生成 `.xcframework`。  
- **Trunk 推送失败提示权限？ / Permission errors when pushing to Trunk?**  
  请确认邮箱已完成 `pod trunk register` 验证；可通过 `pod trunk me` 查看当前账号状态。  
- **如何更新依赖版本？ / How to update dependency versions?**  
  在 `TopStepAIBudsSDK.podspec` 中调整 `s.dependency`，重新执行版本号更新与推送流程即可。  

## 项目改进反思 / Post-task Reflection
- 新增 MIT `LICENSE` 文件，满足 CocoaPods 发布审核的基础合规要求。 / Added MIT `LICENSE` to meet CocoaPods compliance.
- `TopStepAIBudsSDK.podspec` 现限制为 arm64 架构，避免在不支持的环境构建。 / Updated podspec to clarify arm64-only delivery.
- README 补充了分步发布指南与常见问题，帮助非专业用户独立完成发版。 / README now lists step-by-step release guidance and FAQs for non-technical users.
- 后续优化方向：获取并整合模拟器架构的二进制包，降低本地调试门槛。 / Future improvement: bundle simulator slices to simplify local simulator debugging.

