#
# Be sure to run `pod lib lint RHNetwork.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RHNetwork'
  s.version          = '0.1.1'
  s.summary          = 'Moya封装'

  s.description      = <<-DESC
Moya网路请求封装, 可选缓存，RxSwift支持
                       DESC

  s.homepage         = 'https://github.com/495929699/RHNetwork'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'rongheng' => '495929699g@gmail.com' }
  s.source           = { :git => 'https://github.com/495929699/RHNetwork.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.swift_version = '5.0'
  s.cocoapods_version = '>=1.6.0'
  s.pod_target_xcconfig = {
    'SWIFT_VERSION' => '5.0'
  }

  s.source_files = 'RHNetwork/Classes/**/*.swift'
  
  # s.resource_bundles = {
  #   'RHNetwork' => ['RHNetwork/Assets/*.png']
  # }

  s.dependency 'Alamofire', '~>4.8.2'
  s.dependency 'Moya', '~>13.0'
  s.dependency 'RxSwift', '~>4.5'
  s.dependency 'RxCocoa'
  s.dependency 'RxSwiftExtensions.swift', '~>0.1'
  s.dependency 'RHCache', '~>0.1'
  
end
