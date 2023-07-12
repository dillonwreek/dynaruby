#!/usr/bin/env ruby
require "fileutils"

def hello
  puts "Hello !"
end

class Config
  def read_config_file
    @config ||= File.readlines("/etc/dynaruby.conf").map(&:chomp)
  end

  def username
    @config.first
  end

  def password
    @config = "password"
  end

  def hostnames
    @config = "hostnames"
  end
end

config = Config.new

config.read_config_file
