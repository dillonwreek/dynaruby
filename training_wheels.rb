#!/usr/bin/env ruby

def hello
  puts "hello"
end

module Installer
  def os
    hello
    case RUBY_PLATFORM
    when /darwin/
      "mac"
    when /linux/
      "linux"
    when /bsd/
      "bsd"
    end
  end
end

include Installer
Installer.os
