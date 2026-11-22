Pod::Spec.new do |s|
  s.name             = 'olaf_ffi'
  s.version          = '0.0.1'
  s.summary          = 'Olaf acoustic fingerprinting'
  s.description      = <<-DESC
Olaf (Joren Six), vendored under AGPL-3.0 and called through dart:ffi.
                       DESC
  s.homepage         = 'https://github.com/JorenSix/Olaf'
  s.license          = { :file => '../src/third_party/olaf/LICENSE' }
  s.author           = { 'Joren Six' => 'joren.six@esat.kuleuven.be' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) NDEBUG=1',
    'OTHER_CFLAGS' => '-std=gnu11 -D_GNU_SOURCE'
  }
  s.swift_version = '5.0'
end
