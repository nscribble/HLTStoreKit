#
# Be sure to run `pod lib lint HLTStoreKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'HLTStoreKit'
  s.version          = '0.9.2'
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

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'StoreKit', 'Foundation'
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
#  s.script_phase = { :name => "Update Version", :script => "sudo echo '#define HLTStoreKitVersion @\"#{s.version.to_s}\"' >  ${PODS_TARGET_SRCROOT}/HLTStoreKit/Classes/HLTStoreKitVersion.h", :execution_position => :before_compile , :shell_path => "/bin/sh"}
#  s.dependency 'HLTAPIClient'
end
