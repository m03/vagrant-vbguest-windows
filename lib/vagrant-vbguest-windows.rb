begin
  require 'vagrant-vbguest'
rescue LoadError
  raise 'This Vagrant plugin requires the vagrant-vbguest plugin.'
end

# Add the custom translations to the load path.
I18n.load_path << File.expand_path('../../locales/en.yml', __FILE__)
I18n.reload!

require_relative 'vagrant-vbguest-windows/version'
require_relative 'vagrant-vbguest-windows/installer'

module VagrantVbguestWindows
  class Plugin < Vagrant.plugin('2')

    name 'vagrant-vbguest-windows'
    description 'This Vagrant plugin extends vagrant-vbguest, by adding a VagrantVbguest Installer for Windows clients.'
  end
end
