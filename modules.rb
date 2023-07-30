#!/usr/bin/env ruby

module Installer
  def install_method
    p "Installing"
  end
end

class Config
  include Installer
end

class Updater < Config
end

updater = Updater.new
updater.install_method
