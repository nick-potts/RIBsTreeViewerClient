Pod::Spec.new do |s|
  s.name             = 'RIBsTreeViewerClient'
  s.version          = '1.0.2'
  s.summary          = 'Real Time viewing attached RIBs Tree on Browser'

  s.description      = <<-DESC
Real Time viewing attached RIBs Tree on Browser
                       DESC

  s.homepage         = 'https://github.com/srea/RIBsTreeViewerClient'
  s.screenshots     = 'raw.githubusercontent.com/srea/RIBsTreeViewerClient/master/docs/demo.gif'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Yuki Tamazawa' => 'yuki.tamazawa@icloud.com' }
  s.source           = { :git => 'https://github.com/github@nickpotts.com.au/RIBsTreeViewerClient.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'RIBsTreeViewerClient/Sources/**/*'

  s.dependency 'RxSwift', '~> 5.0.1'
  s.dependency 'RIBs', '~> 0.9'

end
