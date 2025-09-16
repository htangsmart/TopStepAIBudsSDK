Pod::Spec.new do |s|
  s.name             = 'TopStepAIBudsSDK'
  s.version          = '1.0.0'
  s.summary          = 'TopStep AI Buds SDK for iOS'
  s.description      = <<-DESC
TopStep AI Buds SDK provides comprehensive functionality for AI-powered earbuds integration,
including device connection, audio processing, and fitness tracking capabilities.
                       DESC

  s.homepage         = 'https://github.com/htangsmart/TopStepAIBudsSDK'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'TopStep' => 'support@topstep.com' }
  s.source           = { :git => 'https://github.com/htangsmart/TopStepAIBudsSDK.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # 主framework文件
  s.vendored_frameworks = 'TopStepAIBudsSDK.xcframework'

  # TopStepAIBudsSDK.framework 通过 @rpath 动态链接这些框架，需要单独安装
  s.dependency 'RxSwift', '6.8.0'
  s.dependency 'RxCocoa', '6.8.0'
  s.dependency 'RxRelay', '6.8.0'
  s.dependency 'ReactiveObjC', '3.1.1'
  s.dependency 'YYModel', '1.0.4'
  s.dependency 'libopus', '1.1'

  # 系统框架依赖
  s.frameworks = 'Foundation', 'UIKit', 'CoreBluetooth', 'AVFoundation', 'CoreAudio', 'AudioToolbox'
  
  # 链接器标志
  s.libraries = 'c++', 'z'
  
  # 编译设置
  s.pod_target_xcconfig = {
    'ENABLE_BITCODE' => 'NO',
    'SWIFT_VERSION' => '5.0'
  }

end
