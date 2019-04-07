Pod::Spec.new do |s|
    s.name         = 'EllipticCurveKit'
    s.version      = '1.0.0'
    s.swift_version = '5.0'
    s.ios.deployment_target = "11.3"
    s.osx.deployment_target = "10.12"
    s.license      = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
    s.summary      = 'Elliptic Curve Cryptography in pure Swift'
    s.homepage     = 'https://github.com/Sajjon/EllipticCurveKit'
    s.author       = { "Alex Cyon" => "alex.cyon@gmail.com" }
    s.source       = { :git => 'https://github.com/Sajjon/EllipticCurveKit.git', :tag => String(s.version) }
    s.source_files = 'Source/**/*.swift'
    s.social_media_url = 'https://twitter.com/alexcyon'
    s.dependency 'BigInt', '~> 3.1'
    s.dependency 'CryptoSwift', '~> 1.0.0'
end