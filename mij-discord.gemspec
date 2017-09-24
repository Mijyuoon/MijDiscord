# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mij-discord/version'

Gem::Specification.new do |spec|
  spec.name          = 'mij-discord'
  spec.version       = MijDiscord::VERSION
  spec.authors       = ['Mijyuoon']
  spec.email         = ['mijyuoon@gmail.com']

  spec.summary       = %q{Discord bot library partially based on Discordrb}
  spec.homepage      = 'https://github.com/Mijyuoon/MijDiscord'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) {|f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rest-client'
  spec.add_dependency 'websocket-client-simple', '>= 0.3.0'

  spec.required_ruby_version = '>= 2.3.0'

  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
end
