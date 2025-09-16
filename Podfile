# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'TSDemo' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for TSDemo

  # TopStep AI Buds SDK 的依赖库
  # TopStepAIBudsSDK.framework 通过 @rpath 动态链接这些框架，需要单独安装
  pod 'RxSwift', '6.8.0'
  pod 'RxCocoa', '6.8.0'
  pod 'RxRelay', '6.8.0'
  pod 'ReactiveObjC', '3.1.1'
  pod 'YYModel', '1.0.4'
  pod 'libopus', '1.1'
  
  # TopStep AI Buds SDK
  pod 'TopStepAIBudsSDK', :path => '.'
  
  # 耳机仓功能库
  pod 'TopStepComKit-Git/ComKit', :git => 'https://github.com/htangsmart/TopStepComKit.git', :branch => 'main'
  pod 'TopStepComKit-Git/FitCoreImp', :git => 'https://github.com/htangsmart/TopStepComKit.git', :branch => 'main'
  pod 'TopStepComKit-Git/SJCoreImp', :git => 'https://github.com/htangsmart/TopStepComKit.git', :branch => 'main'

end

# Ensure all Pods use a minimum iOS deployment target to avoid missing libarclite
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Bump Pods built with too-low targets (e.g., 8.0) to at least 12.0
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      
      # 强制生成framework文件
      if ['RxSwift', 'RxCocoa', 'RxRelay', 'ReactiveObjC', 'YYModel', 'libopus'].include?(target.name)
        config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
        config.build_settings['SKIP_INSTALL'] = 'NO'
      end
    end
  end
end
