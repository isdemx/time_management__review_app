Pod::Spec.new do |s|
  s.name             = 'app_group_directory'
  s.version          = '2.0.0'
  s.summary          = 'Flutter plugin to access shared app group on iOS'
  s.description      = 'Flutter plugin to access shared app group on iOS'
  s.homepage         = 'https://github.com/Albert221/app_group_directory'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Albert Wolszon' => 'unknown@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.ios.deployment_target = '12.0'
end
