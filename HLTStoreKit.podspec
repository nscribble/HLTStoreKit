#
# Be sure to run `pod lib lint HLTStoreKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'HLTStoreKit'
  s.version          = '0.8.5'
  s.summary          = 'HLTStoreKit is to ease your pain for iap.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
HLTStoreKit is to ease your pain for iap. just have a try.
                       DESC

  s.homepage         = 'https://github.com/nscribble/HLTStoreKit.git'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT'}
  s.author           = { 'nscribble' => 'awake.gtd@gmail.com' }
  s.source           = { :git => 'https://github.com/nscribble/HLTStoreKit.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'HLTStoreKit/Classes/**/*'
  
  # s.resource_bundles = {
  #   'HLTStoreKit' => ['HLTStoreKit/Assets/*.png']
  # }

  s.public_header_files = ['HLTStoreKit/Classes/Core/**/*.h', 'HLTStoreKit/Classes/Plugins/**/*.h']
  s.frameworks = 'StoreKit', 'Foundation'
#  s.dependency 'HLTAPIClient'
#  s.pod_target_xcconfig = {}
  s.vendored_libraries = ['libraries/openssl-1.0.1e/lib/libcrypto.a', 'libraries/openssl-1.0.1e/lib/libssl.a']
  s.xcconfig = { "HEADER_SEARCH_PATHS" => "${PODS_ROOT}/#{s.name}/libraries/openssl-1.0.1e/include"}

#  s.subspec 'openssl' do |openssl|
##    openssl.preserve_paths = 'libraries/openssl-1.0.1e/include/openssl/*.h', 'libraries/openssl-1.0.1e/include/LICENSE'
#    openssl.vendored_libraries = 'libraries/openssl-1.0.1e/lib/libcrypto.a', 'libraries/openssl-1.0.1e/lib/libssl.a'
#    openssl.source_files = "libraries/openssl-1.0.1e/**/*"
##    openssl.libraries = 'ssl', 'crypto'
##    openssl.header_dir = "openssl"
##    openssl.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/libraries/openssl-1.0.1e/include/**" }
#  end
end
