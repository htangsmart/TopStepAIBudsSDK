//
//  SceneDelegate.swift
//  TSDemo
//
//  场景代理 - Scene Delegate
//  处理应用启动逻辑，判断是否有缓存设备并跳转到相应页面
//  Handles app launch logic, determines if there's cached device and navigates to appropriate page
//

import UIKit
import TopStepABMateSDK

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // MARK: - Scene Lifecycle
    /// 场景连接时调用 - Called when scene connects
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // 初始化窗口 - Initialize window
        window = UIWindow(windowScene: windowScene)
        
        // 初始化SDK日志 - Initialize SDK logs
        TopStepAIBuds.logsOpen(true)
        
        // 判断是否有缓存设备 - Check if there's cached device
        let rootViewController: UIViewController
        
        if let cachedDevice = DeviceCacheManager.shared.getCachedDevice() {
            // 有缓存设备，进入设备连接页面自动重连 - Has cached device, enter connection page for auto-reconnect
            print("✅ 检测到缓存设备，进入自动重连 - Cached device detected, entering auto-reconnect")
            let connectionVC = DeviceConnectionViewController(deviceInfo: cachedDevice, isAutoReconnect: true)
            rootViewController = UINavigationController(rootViewController: connectionVC)
        } else {
            // 无缓存设备，进入设备选择页面 - No cached device, enter device selection page
            print("ℹ️ 无缓存设备，进入设备选择页面 - No cached device, entering device selection page")
            let scanVC = ScanViewController()
            rootViewController = UINavigationController(rootViewController: scanVC)
        }
        
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

