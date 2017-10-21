# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'vagrant-vbguest-windows/version'

Gem::Specification.new do |spec|
  spec.name          = 'vagrant-vbguest-windows'
  spec.version       = VagrantVbguestWindows::VERSION
  spec.authors       = ['Morrie Winnett']
  spec.email         = ['']
  spec.homepage      = 'https://github.com/m03/vagrant-vbguest-windows'
  spec.license       = 'MIT'
  spec.summary       = 'Adds support for Windows clients to vagrant-vbguest.'
  spec.description   = <<-DESC
    This Vagrant plugin extends vagrant-vbguest, by adding a VagrantVbguest Installer for Windows clients.
  DESC

  spec.bindir        = 'bin'
  spec.require_paths = ['lib']
  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.add_dependency 'i18n', '~> 0.8.0'
  spec.add_dependency 'vagrant-vbguest', '~> 0.15.0'

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'reek', '~> 4.6'
  spec.add_development_dependency 'cane', '~> 3.0'
end
